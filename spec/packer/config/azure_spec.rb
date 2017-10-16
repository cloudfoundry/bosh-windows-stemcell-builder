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
        output_directory: 'some-output-directory',
        os: 'windows2012R2'
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
    context 'windows 2012' do
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
          output_directory: 'some-output-directory',
          os: 'windows2012R2'
        ).provisioners
        expect(provisioners).to eq(
          [
            {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
            {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures2012"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Test-InstalledUpdates"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
            {"type"=>"file", "source"=>"../sshd/OpenSSH-Win64.zip", "destination"=>"C:\\provision\\OpenSSH-Win64.zip"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
            {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS azure -OsVersion windows2012R2"]}
          ].flatten
        )
      end
    end
  end
end
