require 'digest'
require 'tmpdir'
require 'zlib'
require 'nokogiri'

module Stemcell
  class Builder
    class VSphereBase < Base
      def initialize(source_path:, administrator_password:, mem_size:, num_vcpus: , **args)
        @source_path = source_path
        @administrator_password = administrator_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        super(args)
      end
    end

    class VSphereAddUpdates < VSphereBase
      def initialize(**args)
        args[:agent_commit] = ""
        args[:version] = ""
        args[:os] = ""
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
          num_vcpus: @num_vcpus
        ).dump
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:, owner:, organization:, **args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        super(args)
      end

      def build
        run_packer
        image_path, sha = create_image(@output_directory)
        update_list = File.join(@output_directory, 'updates.txt')
        manifest = Manifest::VSphere.new(@version, sha, @os).dump
        super(iaas: 'vsphere-esxi', is_light: false, image_path: image_path, manifest: manifest, update_list: update_list)
      end

      private
      def packer_config
        Packer::Config::VSphere.new(
          administrator_password: @administrator_password,
          source_path: @source_path,
          output_directory: @output_directory,
          mem_size: @mem_size,
          num_vcpus: @num_vcpus,
          product_key: @product_key,
          owner: @owner,
          organization: @organization
        ).dump
      end

      def find_vmx_file(dir)
        pattern = File.join(dir, "*.vmx").gsub('\\', '/')
        files = Dir.glob(pattern)
        if files.length == 0
          raise "No vmx files in directory: #{dir}"
        end
        if files.length > 1
          raise "Too many vmx files in directory: #{files}"
        end
        return files[0]
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
          vmx_file = find_vmx_file(vmx_dir)
          ova_file = File.join(tmpdir, 'image.ova')
          exec_command("ovftool #{vmx_file} #{ova_file}")
          removeNIC(ova_file)
          gzip_file(ova_file, image_file)
          sha1_sum = Digest::SHA1.file(image_file).hexdigest
        end
        [image_file,sha1_sum]
      end
    end
  end
end
