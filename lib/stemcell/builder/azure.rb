require 'date'
require 'open-uri'

module Stemcell
  class Builder
    class Azure < Base
      def initialize(client_id:, client_secret:, tenant_id:, subscription_id:, resource_group_name:,
                     storage_account:, location:, vm_size:, publisher:, offer:, sku:, vm_prefix:, **kwargs)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @resource_group_name = resource_group_name
        @storage_account = storage_account
        @location = location
        @vm_size = vm_size
        @publisher = publisher
        @offer = offer
        @sku = sku
        @vm_prefix = vm_prefix
        super(**kwargs)
      end

      def build
        disk_uri = run_packer
        File.write(File.join(@output_directory, "bosh-stemcell-#{@version}-azure-vhd-uri.txt"), disk_uri.strip)
        manifest = Manifest::Azure.new(@version, @os, @publisher, @offer, @sku).dump
        super(iaas: 'azure-hyperv',
              is_light: true,
              image_path: '',
              manifest: manifest,
              update_list: update_list_path
             )
      end

      def stage_image(disk_uri)
        puts 'TODO: stage azure disk image'
      end

      def publish_image(disk_uri)
        puts 'TODO: publish azure disk image'
      end

      private
        def packer_config
          Packer::Config::Azure.new(
            client_id: @client_id,
            client_secret: @client_secret,
            tenant_id: @tenant_id,
            subscription_id: @subscription_id,
            resource_group_name: @resource_group_name,
            storage_account: @storage_account,
            location: @location,
            vm_size: @vm_size,
            output_directory: @output_directory,
            os: @os,
            version: @version,
            vm_prefix: @vm_prefix,
            mount_ephemeral_disk: @mount_ephemeral_disk,
          ).dump
        end

        def parse_packer_output(packer_output)
          disk_uri = nil
          packer_output.each_line do |line|
            puts line
            disk_uri ||= parse_disk_uri(line)
          end
          disk_uri
        end

        def parse_disk_uri(line)
          return unless line.include?("azure-arm,artifact,0") && line.include?("OSDiskUri:")

          os_disk_uri = (line.split '\n').select do |s|
            s.start_with?("OSDiskUri: ")
          end.first.gsub("OSDiskUri: ", "").strip

          create_signed_url(os_disk_uri)
        end

        def create_signed_url(url)
          one_month_from_now = Date.today + 30
          output, status = Open3.capture2e('az', 'storage', 'blob', 'generate-sas', '--blob-url', url, '--expiry', "#{one_month_from_now.to_s}T00:00:00Z", '--permissions', 'r', '--account-name', @storage_account, '--full-uri', '-o', 'tsv', '--only-show-errors')
          if !status.success?
            raise "Unable to sign URL #{url}:\n#{output}"
          end

          output.lines.last.strip
        end
    end
  end
end
