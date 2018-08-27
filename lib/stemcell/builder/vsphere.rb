require 'digest'
require 'tmpdir'
require 'zlib'
require 'nokogiri'

module Stemcell
  class Builder
    class VSphereBase < Base
      def initialize(source_path:,
                     administrator_password:,
                     mem_size:,
                     num_vcpus:,
                     enable_rdp: false,
                     http_proxy:,
                     https_proxy:,
                     bypass_list:,
                     **args)
        @source_path = source_path
        @administrator_password = administrator_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @enable_rdp = enable_rdp
        @http_proxy = http_proxy
        @https_proxy = https_proxy
        @bypass_list = bypass_list
        super(args)
      end
    end

    class VSphereAddUpdates < VSphereBase
      def initialize(**args)
        args[:agent_commit] = ""
        args[:version] = ""
        super(args)
      end
      def build
        run_packer
      end

      private
      def packer_config
        Packer::Config::VSphereAddUpdates.new(
          administrator_password: @administrator_password,
          source_path: @source_path,
          output_directory: @output_directory,
          mem_size: @mem_size,
          num_vcpus: @num_vcpus,
          os: @os,
          http_proxy: @http_proxy,
          https_proxy: @https_proxy,
          bypass_list: @bypass_list,
          mount_ephemeral_disk: @mount_ephemeral_disk,
        ).dump
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:, owner:, organization:, new_password:, skip_windows_update: false, **args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        @new_password = new_password
        @skip_windows_update = skip_windows_update
        super(args)
      end

      def build
        run_packer
        run_stembuild
      end

      def rename_stembuild_output
        # stembuild will output a tgz file with the trimmed down version, but we want to retain the original version in the filename
        new_filename = "bosh-stemcell-#{@version}-vsphere-esxi-#{@os}-go_agent.tgz"
        puts "renaming stemcell to #{new_filename}"
        File.rename Dir[File.join(@output_directory, "*.tgz")].first, File.join(@output_directory, new_filename)
      end

      private
      def packer_config
        Packer::Config::VSphere.new(
          administrator_password: @administrator_password,
          new_password: @new_password,
          source_path: @source_path,
          output_directory: @output_directory,
          mem_size: @mem_size,
          num_vcpus: @num_vcpus,
          product_key: @product_key,
          owner: @owner,
          organization: @organization,
          os: @os,
          enable_rdp: @enable_rdp,
          skip_windows_update: @skip_windows_update,
          http_proxy: @http_proxy,
          https_proxy: @https_proxy,
          bypass_list: @bypass_list,
          mount_ephemeral_disk: @mount_ephemeral_disk,
        ).dump
      end

      def find_file_by_extn(dir, extn)
        pattern = File.join(dir, "*.#{extn}").gsub('\\', '/')
        files = Dir.glob(pattern)
        if files.length == 0
          raise "No #{extn} files in directory: #{dir}"
        end
        if files.length > 1
          raise "Too many #{extn} files in directory: #{files}"
        end
        return files[0]
      end

      def run_stembuild
        vmdk_file = find_file_by_extn(@output_directory, "vmdk")
        case @os
        when 'windows2016'
          os_flag = '2016'
        when 'windows1803'
          os_flag = '1803'
        else
          os_flag = '2012R2'
        end

        Stembuild.new(vmdk_file, @version, @output_directory, os_flag).run

        rename_stembuild_output
      end

      def gzip_file(name, output)
        Zlib::GzipWriter.open(output) do |gz|
          File.open(name) do |fp|
            while chunk = fp.read(32 * 1024) do
              gz.write chunk
            end
          end
          gz.close
        end
      end

      def removeNIC(ova_file_name)
        Stemcell::Packager.removeNIC(ova_file_name)
      end

      def create_image(vmx_dir)
        sha1_sum=''
        image_file = File.join(vmx_dir, 'image')
        Dir.mktmpdir do |tmpdir|
          vmx_file = find_file_by_extn(vmx_dir, "vmx")
          ova_file = File.join(tmpdir, 'image.ova')
          exec_command("ovftool '#{vmx_file}' '#{ova_file}'")
          removeNIC(ova_file)
          gzip_file(ova_file, image_file)
          sha1_sum = Digest::SHA1.file(image_file).hexdigest
        end
        [image_file,sha1_sum]
      end

      class Stembuild
        def initialize(vmdk_file, version_flag, output_directory, os_flag)
          @cmd = "stembuild -vmdk \"#{vmdk_file}\" -v \"#{version_flag}\" -output \"#{output_directory}\" -os #{os_flag}"
        end

        def run
          puts "running stembuild command: [[ #{@cmd} ]]"
          `#{@cmd}`
        end
      end
    end
  end
end
