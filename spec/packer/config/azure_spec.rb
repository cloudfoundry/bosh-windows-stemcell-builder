require 'packer/config'

describe Packer::Config::Azure do
  describe 'builders' do
    it 'returns the expected builders' do
      builders = Packer::Config::Azure.new(
        client_id: 'some-client-id',
        client_secret: 'some-client-secret',
        tenant_id: 'some-tenant-id',
        subscription_id: 'some-subscription-id',
        object_id: 'some-object-id',
        resource_group_name: 'some-resource-group-name',
        storage_account: 'some-storage-account',
        location: 'some-location',
        vm_size: 'some-vm-size',
        admin_password: 'some-admin-password',
        output_directory: 'some-output-directory'
      ).builders
      expect(builders[0]).to eq(
        'type' => 'azure-arm',
        'client_id' => 'some-client-id',
        'client_secret' => 'some-client-secret',
        'tenant_id' => 'some-tenant-id',
        'subscription_id' => 'some-subscription-id',
        'object_id' => 'some-object-id',

        'resource_group_name' => 'some-resource-group-name',
        'storage_account' => 'some-storage-account',
        'capture_container_name' => 'packer-stemcells',
        'capture_name_prefix' => 'bosh-stemcell',
        'image_publisher' => 'MicrosoftWindowsServer',
        'image_offer' => 'WindowsServer',
        'image_sku' => '2012-R2-Datacenter',
        'location' => 'some-location',
        'vm_size' => 'some-vm-size',
        'os_type' => 'Windows',

        'communicator' => 'winrm',
        'winrm_use_ssl' => 'true',
        'winrm_insecure' => 'true',
        'winrm_timeout' => '1h',
        'winrm_username' => 'packer'
      )
    end
  end

  describe 'provisioners' do
    it 'returns the expected provisioners' do
      allow(SecureRandom).to receive(:hex).and_return("some-password")
      provisioners = Packer::Config::Azure.new(
        client_id: 'some-client-id',
        client_secret: 'some-client-secret',
        tenant_id: 'some-tenant-id',
        subscription_id: 'some-subscription-id',
        object_id: 'some-object-id',
        resource_group_name: 'some-resource-group-name',
        storage_account: 'some-storage-account',
        location: 'some-location',
        vm_size: 'some-vm-size',
        admin_password: 'some-admin-password',
        output_directory: 'some-output-directory'
      ).provisioners
      expect(provisioners).to eq(
        [
          Packer::Config::Provisioners::BOSH_PSMODULES,
          Packer::Config::Provisioners::NEW_PROVISIONER,
          Packer::Config::Provisioners::INSTALL_CF_FEATURES,
          Packer::Config::Provisioners::install_windows_updates,
          Packer::Config::Provisioners::PROTECT_CF_CELL,
          Packer::Config::Provisioners.install_agent('azure'),
          Packer::Config::Provisioners::CLEAR_PROVISIONER,
          Packer::Config::Provisioners::sysprep_shutdown('azure')
        ].flatten
      )
    end
  end
end
