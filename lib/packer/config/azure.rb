require 'securerandom'

module Packer
  module Config
    class Azure < Base
      def initialize(client_id, client_secret, tenant_id, subscription_id, object_id, admin_password)
        @client_id = client_id
        @client_secret = client_secret
        @tenant_id = tenant_id
        @subscription_id = subscription_id
        @object_id = object_id
        @admin_password = admin_password
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

            'resource_group_name' => 'koala-res-group',
            'storage_account' => 'koalapremiumstore',
            'capture_container_name' => 'packer-test',
            'capture_name_prefix' => 'stemcell',
            'image_publisher' => 'MicrosoftWindowsServer',
            'image_offer' => 'WindowsServer',
            'image_sku' => '2012-R2-Datacenter',
            'location' => 'East US',
            'vm_size' => 'Standard_DS3_v2',
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
