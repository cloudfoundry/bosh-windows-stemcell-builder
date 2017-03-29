require 'packer/config'

describe Packer::Config::Azure do
  describe 'builders' do
    it 'returns the expected builders' do
      builders = Packer::Config::Azure.new(
        'some-client-id',
        'some-client-secret',
        'some-tenant-id',
        'some-subscription-id',
        'some-object-id',
        ''
      ).builders
      expect(builders[0]).to eq(
        'type' => 'azure-arm',
        'client_id' => 'some-client-id',
        'client_secret' => 'some-client-secret',
        'tenant_id' => 'some-tenant-id',
        'subscription_id' => 'some-subscription-id',
        'object_id' => 'some-object-id',

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
      )
    end
  end

  describe 'provisioners' do
    it 'returns the expected provisioners' do
      provisioners = Packer::Config::Azure.new(
        'some-client-id',
        'some-client-secret',
        'some-tenant-id',
        'some-subscription-id',
        'some-object-id',
        'some-admin-password'
      ).provisioners
      expect(provisioners).to eq(
        [
            Packer::Config::Provisioners::CREATE_PROVISION_DIR,
            Packer::Config::Provisioners::UPLOAD_BOSH_PSMODULES,
            Packer::Config::Provisioners::INSTALL_BOSH_PSMODULES,
            Packer::Config::Provisioners::UPLOAD_AGENT,
            Packer::Config::Provisioners.install_agent("azure"),
            Packer::Config::Provisioners::Azure.create_admin('some-admin-password'),
            Packer::Config::Provisioners::INSTALL_CF_FEATURES,
            Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
            Packer::Config::Provisioners::DISABLE_SERVICES,
            Packer::Config::Provisioners::SET_FIREWALL,
            Packer::Config::Provisioners::DISABLE_WINRM_STARTUP,
            Packer::Config::Provisioners::CLEANUP_ARTIFACTS,
            Packer::Config::Provisioners::Azure::SYSPREP_SHUTDOWN
        ]
      )
    end
  end
end
