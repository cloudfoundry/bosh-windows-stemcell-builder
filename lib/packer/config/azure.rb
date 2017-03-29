require 'securerandom'

module Packer
  module Config
    class Azure < Base
      def initialize(client_id, client_secret, tenant_id, subscription_id,
                     object_id, resource_group_name, storage_account, location,
                     vm_size, admin_password)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @object_id = object_id
        @admin_password = admin_password
        @resource_group_name = resource_group_name
        @storage_account = storage_account
        @location = location
        @vm_size = vm_size
      end

      def builders
        [
          {
            'type' => 'azure-arm',
            'client_id' => @client_id,
            'client_secret' => @client_secret,
            'tenant_id' => @tenant_id,
            'subscription_id' => @subscription_id,
            'object_id' => @object_id,

            'resource_group_name' => @resource_group_name,
            'storage_account' => @storage_account,
            'capture_container_name' => 'packer-stemcells',
            'capture_name_prefix' => 'bosh-stemcell',
            'image_publisher' => 'MicrosoftWindowsServer',
            'image_offer' => 'WindowsServer',
            'image_sku' => '2012-R2-Datacenter',
            'location' => @location,
            'vm_size' => @vm_size,
            'os_type' => 'Windows',

            'communicator' => 'winrm',
            'winrm_use_ssl' => 'true',
            'winrm_insecure' => 'true',
            'winrm_timeout' => '3m',
            'winrm_username' => 'packer'
          }
        ]
      end

      def provisioners
        [
          Provisioners::CREATE_PROVISION_DIR,
          Provisioners::UPLOAD_BOSH_PSMODULES,
          Provisioners::INSTALL_BOSH_PSMODULES,
          Provisioners::UPLOAD_AGENT,
          Provisioners.install_agent("azure"),
          Provisioners::Azure.create_admin(@admin_password),
          Provisioners::INSTALL_CF_FEATURES,
          Provisioners::CLEANUP_WINDOWS_FEATURES,
          Provisioners::DISABLE_SERVICES,
          Provisioners::SET_FIREWALL,
          Provisioners::DISABLE_WINRM_STARTUP,
          Provisioners::CLEANUP_ARTIFACTS,
          Provisioners::Azure::SYSPREP_SHUTDOWN
        ]
      end
    end
  end
end
