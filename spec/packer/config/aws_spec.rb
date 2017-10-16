require 'packer/config'

describe Packer::Config::Aws do
  describe 'builders' do
    it 'returns the expected builders' do
      regions = [
        {
          'name' => 'region1',
          'ami_name' => 'ami1',
          'base_ami' => 'baseami1',
          'vpc_id' => 'vpc1',
          'subnet_id' => 'subnet1',
          'security_group' => 'sg1'
        }
      ]
      builders = Packer::Config::Aws.new('accesskey',
                                         'secretkey',
                                         regions,
                                         'some-output-directory',
                                         'windows2012R2').builders
      expect(builders[0]).to include(
        'name' => 'amazon-ebs-region1',
        'type' => 'amazon-ebs',
        'access_key' => 'accesskey',
        'secret_key' => 'secretkey',
        'region' => 'region1',
        'source_ami' => 'baseami1',
        'instance_type' => 'm4.xlarge',
        'vpc_id' => 'vpc1',
        'subnet_id' => 'subnet1',
        'associate_public_ip_address' => true,
        'communicator' => 'winrm',
        'winrm_username' => 'Administrator',
        'winrm_timeout' => '1h',
        'user_data_file' => 'scripts/aws/setup_winrm.txt',
        'security_group_id' => 'sg1',
        'ami_groups' => 'all'
      )
      expect(builders[0]['ami_name']).to match(/BOSH-.*-region1/)
    end
  end

  describe 'provisioners' do
    context 'windows 2012' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Aws.new('', '', [], 'some-output-directory', 'windows2012R2').provisioners
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
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "List-InstalledUpdates | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
            {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"some-output-directory/updates.txt", "direction"=>"download"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS aws -OsVersion windows2012R2"]}
          ].flatten
        )
      end
    end
  end
end
