require 'packer/config'
require 'timecop'

describe Packer::Config do
  before(:each) do
    Timecop.freeze(Time.now.getutc)
  end

  after(:each) do
    Timecop.return
  end

  describe 'VSphereAddUpdates' do
    describe 'builders' do
      it 'returns the expected builders' do
        builders = Packer::Config::VSphereAddUpdates.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2'
        ).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-vmx',
          'source_path' => 'source_path',
          'headless' => false,
          'boot_wait' => '2m',
          'communicator' => 'winrm',
          'winrm_username' => 'Administrator',
          'winrm_password' => 'password',
          'winrm_timeout' => '6h',
          'winrm_insecure' => true,
          'vm_name' => 'packer-vmx',
          'shutdown_command' => "C:\\Windows\\System32\\shutdown.exe /s",
          'shutdown_timeout' => '1h',
          'vmx_data' => {
            'memsize' => '1000',
            'numvcpus' => '1',
            'displayname' => "packer-vmx-#{Time.now.getutc.to_i}"
          },
          'output_directory' => 'output_directory'
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")

        provisioners = Packer::Config::VSphereAddUpdates.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2'
        ).provisioners
        expect(provisioners).to eq(
          [
            {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
            {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Test-InstalledUpdates"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-Log"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          ].flatten
        )
      end
    end
  end

  describe 'VSphere' do
    describe 'builders' do
      it 'returns the expected builders' do
        builders = Packer::Config::VSphere.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          product_key: 'key',
          organization: 'me',
          owner: 'me',
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2'
        ).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-vmx',
          'source_path' => 'source_path',
          'headless' => false,
          'boot_wait' => '2m',
          'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword password -ProductKey key -Owner me -Organization me',
          'shutdown_timeout' => '1h',
          'communicator' => 'winrm',
          'ssh_username' => 'Administrator',
          'winrm_username' => 'Administrator',
          'winrm_password' => 'password',
          'winrm_timeout' => '1h',
          'winrm_insecure' => true,
          'vm_name' => 'packer-vmx',
          'vmx_data' => {
            'memsize' => '1000',
            'numvcpus' => '1',
            'displayname' => "packer-vmx-#{Time.now.getutc.to_i}"
          },
          'output_directory' => 'output_directory',
          'skip_clean_files' => true
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        stemcell_deps_dir = Dir.mktmpdir('vsphere')
        ENV['STEMCELL_DEPS_DIR'] = stemcell_deps_dir

        allow(SecureRandom).to receive(:hex).and_return('some-password')

        provisioners = Packer::Config::VSphere.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          product_key: 'key',
          organization: 'me',
          owner: 'me',
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2'
        ).provisioners
        expect(provisioners).to include(
          {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
          {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h"},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Test-InstalledUpdates"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
          # {"type"=>"file", "source"=>"/var/folders/44/zr3txl1n45b23kd2kgx1xqq00000gn/T/vsphere20170526-23301-1fv8m07/lgpo/LGPO.exe", "destination"=>"C:\\windows\\LGPO.exe"},
          {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip'"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "List-InstalledUpdates | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
          {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"output_directory/updates.txt", "direction"=>"download"},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Optimize-Disk"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Compress-Disk"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
        )

        FileUtils.rm_rf(stemcell_deps_dir)
        ENV.delete('STEMCELL_DEPS_DIR')
      end
    end
  end
end
