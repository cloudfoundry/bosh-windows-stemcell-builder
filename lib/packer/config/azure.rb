require 'securerandom'
require 'erb'
require 'json'

module Packer
  module Config
    class Azure
      def initialize(client_id:, client_secret:, tenant_id:, subscription_id:, resource_group_name:, storage_account:, location:, vm_size:, os:, output_directory:, vm_prefix: '', mount_ephemeral_disk: false)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @resource_group_name = resource_group_name
        @storage_account = storage_account
        @location = location
        @vm_size = vm_size
        @os = os
        @output_directory = output_directory
        @vm_prefix = vm_prefix.empty? ? 'packer' : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
      end

      def builders
        [
            {
                'type' => 'azure-arm',
                'client_id' => @client_id,
                'client_secret' => @client_secret,
                'tenant_id' => @tenant_id,
                'subscription_id' => @subscription_id,
                'resource_group_name' => @resource_group_name,
                'temp_resource_group_name' => "#{@vm_prefix}-#{Time.now.to_i}",
                'storage_account' => @storage_account,
                'capture_container_name' => 'packer-stemcells',
                'capture_name_prefix' => 'bosh-stemcell',
                'image_publisher' => 'MicrosoftWindowsServer',
                'image_offer' => ENV['BASE_IMAGE_OFFER'],
                'image_sku' => ENV['BASE_IMAGE'],
                'location' => @location,
                'vm_size' => @vm_size,
                'os_type' => 'Windows',
                'os_disk_size_gb' => os_disk_size_gb,
                'communicator' => 'winrm',
                'winrm_use_ssl' => 'true',
                'winrm_insecure' => 'true',
                'winrm_timeout' => '1h',
                'winrm_username' => 'packer'
            }
        ]
      end

      def provisioners
        ProvisionerFactory.new(@os, 'azure', @mount_ephemeral_disk).dump
      end

      def dump
        JSON.dump(
            'builders' => builders,
            'provisioners' => provisioners
        )
      end

      private

      def os_disk_size_gb
        if @os == 'windows2012R2'
          128
        else
          30
        end
      end
    end
  end
end
