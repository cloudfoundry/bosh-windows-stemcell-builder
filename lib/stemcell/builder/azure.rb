require 'open-uri'

module Stemcell
  class Builder
    class Azure < Base
      def initialize(client_id:, client_secret:, tenant_id:, subscription_id:, object_id:, admin_password:, **args)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @object_id = object_id
        @admin_password = admin_password
        super(args)
      end

      def build
        image_path = run_packer
        sha = Digest::SHA1.file(image_path).hexdigest
        manifest = Manifest::Azure.new('bosh-azure-stemcell-name', @version, sha, @os).dump
        super(iaas: 'azure',
              is_light: false,
              image_path: image_path,
              manifest: manifest,
              update_list: File.join(@output_directory, 'updates.txt')
             )
      end

      private
        def packer_config
          Packer::Config::Azure.new(
            @client_id,
            @client_secret,
            @tenant_id,
            @subscription_id,
            @object_id,
            @admin_password
          ).dump
        end

        def parse_packer_output(packer_output)
          disk_uri = nil
          packer_output.each_line do |line|
            puts line
            disk_uri ||= parse_disk_uri(line)
          end
          # download_disk(disk_uri)
          # Packager.package_image(image_path: File.join(@output_directory, 'root.vhd'), archive: true, output_directory: @output_directory)
          puts "DISK URI: #{disk_uri}"
        end

        def parse_disk_uri(line)
          unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
            return
          end
          (line.split '\n').select do |s|
            s.start_with?("OSDiskUriReadOnlySas: ")
          end.first.gsub("OSDiskUriReadOnlySas: ", "")
        end

        def download_disk(disk_uri)
          Downloader.download(disk_uri, File.join(@output_directory, 'root.vhd'))
        end
    end
  end
end
