require 'packer/config'

describe Packer::Config::Gcp do
  describe 'builders' do
    it 'returns the expected builders' do
      account_json = 'some-account-json'
      project_id = 'some-project-id'
      source_image = 'some-base-image'
      image_family = 'some-image-family'
      output_dir = 'some-output-directory'
      builders = Packer::Config::Gcp.new(
        account_json,
        project_id,
        source_image,
        output_dir,
        image_family,
        'windows2012R'
      ).builders
      expect(builders[0]).to include(
        'type' => 'googlecompute',
        'account_file' => account_json,
        'project_id' => project_id,
        'tags' => ['winrm'],
        'source_image' => source_image,
        'image_family' => image_family,
        'zone' => 'us-east1-c',
        'disk_size' => 50,
        'machine_type' => 'n1-standard-4',
        'omit_external_ip' => false,
        'communicator' => 'winrm',
        'winrm_username' => 'winrmuser',
        'winrm_use_ssl' => false,
        'winrm_timeout' => '1h',
        'metadata' => {
          'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/gcp/setup-winrm.ps1'
        }
      )
      expect(builders[0]['image_name']).to match(/packer-\d+/)
    end
  end

  describe 'provisioners' do
    context 'windows 2012' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json, 'some-output-directory','windows-2012-r2', 'windows2012R2').provisioners
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
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS gcp -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "List-InstalledUpdates | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
            {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"some-output-directory/updates.txt", "direction"=>"download"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS gcp -OsVersion windows2012R2"]}
          ].flatten
        )
      end
    end
    context 'windows 2016' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json, 'some-output-directory','windows-2012-r2', 'windows2016').provisioners
        expect(provisioners).to eq(
          [
            {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
            {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Install-CFFeatures2016", "restart_timeout"=>"1h"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Docker2016 -ReduceMTU"]},
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
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS gcp -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "List-InstalledUpdates | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
            {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"some-output-directory/updates.txt", "direction"=>"download"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS gcp -OsVersion windows2012R2"]}
          ].flatten
        )
      end
    end
  end
end
