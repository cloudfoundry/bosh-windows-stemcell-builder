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
          os: 'windows2012R2',
          http_proxy: '',
          https_proxy: '',
          bypass_list: ''
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
          os: 'windows2012R2',
          http_proxy: 'foo',
          https_proxy: 'bar',
          bypass_list: 'bee'
        ).provisioners
        expect(provisioners).to eq(
          [
            {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
            {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
            {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                              'trap { $host.SetShouldExit(1) }',
                                              'Set-ProxySettings foo bar bee']},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Test-InstalledUpdates"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-Log"]},
            {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                               'trap { $host.SetShouldExit(1) }',
                                               'Clear-ProxySettings']},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Start-Sleep -Seconds 900; Restart-Computer -Force", "restart_timeout"=>"1h"},
            {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Start-Sleep -Seconds 900; Restart-Computer -Force", "restart_timeout"=>"1h"}
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
          os: 'windows2012R2',
          enable_rdp: false,
          enable_kms: false,
          kms_host: '',
          new_password: 'new-password',
          http_proxy: '',
          https_proxy: '',
          bypass_list: ''
        ).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-vmx',
          'source_path' => 'source_path',
          'headless' => false,
          'boot_wait' => '2m',
          'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -ProductKey key -Owner me -Organization me',
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

      it 'adds the EnableRdp flag to shutdown command' do
        builders = Packer::Config::VSphere.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          product_key: 'key',
          organization: 'me',
          owner: 'me',
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2',
          enable_rdp: true,
          enable_kms: false,
          kms_host: '',
          new_password: 'new-password',
          http_proxy: '',
          https_proxy: '',
          bypass_list: ''
        ).builders
        expect(builders[0]['shutdown_command']).to eq 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -ProductKey key -Owner me -Organization me -EnableRdp'
      end

      it 'does not include -ProductKey if product key is empty string' do
        builders = Packer::Config::VSphere.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          product_key: '',
          organization: 'me',
          owner: 'me',
          administrator_password: 'password',
          source_path: 'source_path',
          os: 'windows2012R2',
          enable_rdp: true,
          enable_kms: false,
          kms_host: '',
          new_password: 'new-password',
          http_proxy: '',
          https_proxy: '',
          bypass_list: ''
        ).builders
        expect(builders[0]['shutdown_command']).to eq 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -Owner me -Organization me -EnableRdp'
      end
    end

    describe 'provisioners' do
      context 'windows 2016' do
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
            os: 'windows2016',
            enable_rdp: false,
            enable_kms: false,
            kms_host: '',
            new_password: 'new-password',
            http_proxy: 'foo',
            https_proxy: 'bar',
            bypass_list: 'bee'
          ).provisioners
          expected_provisioners_except_lgpo =
            [
              {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
              {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
              {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                                'trap { $host.SetShouldExit(1) }',
                                                'Set-ProxySettings foo bar bee']},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
              {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Install-CFFeatures2016", "restart_timeout"=>"1h"},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
              {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h"},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
              ## omitting LGPO provisioner because random string in it
              {"type"=>"file", "source"=>"../sshd/OpenSSH-Win64.zip", "destination"=>"C:\\provision\\OpenSSH-Win64.zip"},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
              {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-Hotfix | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
            {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"output_directory/updates.txt", "direction"=>"download"},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Optimize-Disk"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Compress-Disk"]},
              {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                                 'trap { $host.SetShouldExit(1) }',
                                                 'Clear-ProxySettings']},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
            ].flatten
          expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
          provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
          expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
        end
      end

      context 'windows 2012' do
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
            os: 'windows2012R2',
            enable_rdp: false,
            enable_kms: false,
            kms_host: '',
            new_password: 'new-password',
            http_proxy: 'foo',
            https_proxy: 'bar',
            bypass_list: 'bee'
          ).provisioners
          expected_provisioners_except_lgpo = [
            {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
            {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
            {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                              'trap { $host.SetShouldExit(1) }',
                                              'Set-ProxySettings foo bar bee']},
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
            # {"type"=>"file", "source"=>"/var/folders/44/zr3txl1n45b23kd2kgx1xqq00000gn/T/vsphere20170526-23301-1fv8m07/lgpo/LGPO.exe", "destination"=>"C:\\windows\\LGPO.exe"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
            {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip'"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-Hotfix | Out-File -FilePath \"C:\\updates.txt\" -Encoding ASCII"]},
            {"type"=>"file", "source"=>"C:\\updates.txt", "destination"=>"output_directory/updates.txt", "direction"=>"download"},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Optimize-Disk"]},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Compress-Disk"]},
            {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                               'trap { $host.SetShouldExit(1) }',
                                               'Clear-ProxySettings']},
            {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          ]
          expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
          provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
          expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)


          FileUtils.rm_rf(stemcell_deps_dir)
          ENV.delete('STEMCELL_DEPS_DIR')
        end
      end

      it 'adds the kms host provisioner' do
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
          os: 'windows2012R2',
          enable_rdp: false,
          enable_kms: true,
          kms_host: "myhost.com",
          new_password: 'new-password',
          http_proxy: '',
          https_proxy: '',
          bypass_list: ''
        ).provisioners
        expect(provisioners).to include(
          {
            "type"=>"powershell",
            "inline"=>
            [
              "$ErrorActionPreference = \"Stop\";",
              "netsh advfirewall firewall add rule name=\"Open inbound 1688 for KMS Server\" dir=in action=allow protocol=TCP localport=1688",
              "netsh advfirewall firewall add rule name=\"Open outbound 1688 for KMS Server\" dir=out action=allow protocol=TCP localport=1688",
              "cscript //B 'C:\\Windows\\System32\\slmgr.vbs' /skms myhost.com:1688"
            ]
          }
        )

        FileUtils.rm_rf(stemcell_deps_dir)
        ENV.delete('STEMCELL_DEPS_DIR')
      end
    end
  end
end
