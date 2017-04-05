require 'open-uri'
require 'active_support'
require 'active_support/core_ext'

module Stemcell
  class Builder
    class Azure < Base
      def initialize(client_id:, client_secret:, tenant_id:, subscription_id:, object_id:, resource_group_name:,
                     storage_account:, location:, vm_size:, admin_password:, publisher:, offer:, sku:, **args)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @object_id = object_id
        @resource_group_name = resource_group_name
        @storage_account = storage_account
        @location = location
        @vm_size = vm_size
        @admin_password = admin_password
        @publisher = publisher
        @offer = offer
        @sku = sku
        super(args)
      end

      def build
        disk_uri = run_packer
        File.write(File.join(@output_directory, "bosh-stemcell-#{@version}-azure-vhd-uri.txt"), disk_uri.strip)
        manifest = Manifest::Azure.new(@version, @os, @publisher, @offer, @sku).dump
        super(iaas: 'azure',
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
            object_id: @object_id,
            resource_group_name: @resource_group_name,
            storage_account: @storage_account,
            location: @location,
            vm_size: @vm_size,
            admin_password: @admin_password,
            output_directory: @output_directory
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
          unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
            return
          end
          url = (line.split '\n').select do |s|
            s.start_with?("OSDiskUriReadOnlySas: ")
          end.first.gsub("OSDiskUriReadOnlySas: ", "")

          domain = (url.split '?')[0]
          now = Time.now.utc
          next_year = now + 1.year
          yesterday = now - 1.day
          decoded_url = CGI.unescape(url)
          params = CGI.parse ((decoded_url.chomp.split '?')[1])

          params['se']=next_year.iso8601
          params['st']=yesterday.iso8601
          params['sr']='c'
          params['sp']='rl'

          new_params = CGI.unescape(URI.encode_www_form params)

          domain + "?" + new_params
        end
    end
  end
end
