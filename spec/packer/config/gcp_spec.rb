require 'packer/config'

describe Packer::Config::Gcp do
  describe 'builders' do
    before :each do
      Timecop.freeze
    end

    after :each do
      Timecop.return
    end

    let (:builders) { Packer::Config::Gcp.new(
        account_json: 'some-account-json',
        project_id: 'some-project-id',
        source_image: 'some-source-image',
        output_directory: '',
        image_family: 'some-image-family',
        os: os,
        vm_prefix: 'some-vm-prefix',
    ).builders }

    let (:baseline_builders) { {
            'type' => 'googlecompute',
            'account_file' => 'some-account-json',
            'project_id' => 'some-project-id',
            'tags' => ['winrm'],
            'source_image' => 'some-source-image',
            'image_family' => 'some-image-family',
            'zone' => 'us-east1-c',
            'disk_size' => 32,
            'machine_type' => 'n1-standard-4',
            'omit_external_ip' => false,
            'communicator' => 'winrm',
            'winrm_username' => 'winrmuser',
            'winrm_use_ssl' => false,
            'winrm_timeout' => '1h',
            'metadata' => {
                'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/gcp/setup-winrm.ps1',
                'name' => "some-vm-prefix-#{Time.now.to_i}"
            }

    } }

    context 'all os versions' do
      let(:os) { '' }

      it 'returns the expected builders' do
        expect(builders[0]).to include(baseline_builders)
        expect(builders[0]['image_name']).to match(/packer-\d+/)
      end
    end

    context 'windows2012R2' do
      let (:os) { 'windows2012R2' }

      it 'returns the expected builders with a 100GB root disk' do
        expect(builders[0]).to include(baseline_builders.merge({ 'disk_size' => 100 }))
      end
    end

    context 'when vm_prefix is empty' do
      it 'defaults to packer' do
        builders = Packer::Config::Gcp.new(
          account_json: '',
          project_id: '',
          source_image: '',
          output_directory: '',
          image_family: '',
          os: '',
          vm_prefix: '',
        ).builders
        expect(builders[0]['metadata']).to include(
          'name' => "packer-#{Time.now.to_i}"
        )
      end
    end
  end

  describe 'provisioners' do
    before(:each) do
      @stemcell_deps_dir = Dir.mktmpdir('gcp')
      ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir
    end

    after(:each) do
      FileUtils.rm_rf(@stemcell_deps_dir)
      ENV.delete('STEMCELL_DEPS_DIR')
    end

    context 'windows 2012' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new(
          account_json: '{}',
          project_id: '',
          source_image: '{}',
          output_directory: 'some-output-directory',
          image_family: '',
          os: 'windows2012R2',
          vm_prefix: '',
          mount_ephemeral_disk: false,
        ).provisioners
        expected_provisioners_except_lgpo = [
          {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
          {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
          {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                            'trap { $host.SetShouldExit(1) }',
                                            'Set-ProxySettings ']},
          {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                          'trap { $host.SetShouldExit(1) }',
                                          'Upgrade-PSVersion'],
                                  'elevated_user' => 'Administrator',
                                  'elevated_password' => "{{.WinRMPassword}}"
          },
          {"type" => "windows-restart" },
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures"]},
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-CVE-2015-6161"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-CVE-2017-8529"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-CredSSP"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-DCOM"]},
          {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                             'trap { $host.SetShouldExit(1) }',
                                             'Clear-ProxySettings']},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS gcp"]}
        ].flatten

        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end
    end

    context 'windows 2016' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new(
            account_json: '{}',
            project_id: '',
            source_image: '{}',
            output_directory: 'some-output-directory',
            image_family: '',
            os: 'windows2016',
            vm_prefix: ''
        ).provisioners
        expected_provisioners_except_lgpo = [
          {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
          {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
          {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                            'trap { $host.SetShouldExit(1) }',
                                            'Set-ProxySettings ']},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Remove-DockerPackage", "restart_timeout"=>"1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Install-CFFeatures", "restart_timeout"=>"1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
          {"type"=>"file", "source"=>"../sshd/OpenSSH-Win64.zip", "destination"=>"C:\\provision\\OpenSSH-Win64.zip"},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
          {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS gcp -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                             'trap { $host.SetShouldExit(1) }',
                                             'Clear-ProxySettings']},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS gcp"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end
    end

    context 'windows 1803' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new(
          account_json: '{}',
          project_id: '',
          source_image: '{}',
          output_directory: 'some-output-directory',
          image_family: '',
          os: 'windows1803',
          vm_prefix: ''
        ).provisioners
        expected_provisioners_except_lgpo = [
          {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip"},
          {"type" => "powershell", "scripts" => ["scripts/install-bosh-psmodules.ps1"]},
          {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            'Set-ProxySettings ']},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Remove-DockerPackage",  "restart_timeout" => "1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type" => "windows-restart", "restart_command" => "powershell.exe -Command Install-CFFeatures", "restart_timeout" => "1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
          {"type" => "windows-restart", "restart_command" => "powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout" => "12h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
          {"type" => "file", "source" => "../sshd/OpenSSH-Win64.zip", "destination" => "C:\\provision\\OpenSSH-Win64.zip"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
          {"type" => "file", "source" => "build/agent.zip", "destination" => "C:\\provision\\agent.zip"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS gcp -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            'Clear-ProxySettings']},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS gcp"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end
    end
  end
end
