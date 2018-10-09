require 'packer/config'
require 'timecop'

describe Packer::Config::Azure do
  describe 'builders' do
    before :each do
      allow(ENV).to receive(:[]).with("BASE_IMAGE_OFFER").and_return("some-base-image-offer")
      allow(ENV).to receive(:[]).with("BASE_IMAGE").and_return("some-base-image")
      Timecop.freeze
    end

    after :each do
      Timecop.return
    end

    let (:builders) { Packer::Config::Azure.new(
        client_id: 'some-client-id',
        client_secret: 'some-client-secret',
        tenant_id: 'some-tenant-id',
        subscription_id: 'some-subscription-id',
        object_id: 'some-object-id',
        resource_group_name: 'some-resource-group-name',
        storage_account: 'some-storage-account',
        location: 'some-location',
        vm_size: 'some-vm-size',
        output_directory: '',
        os: os,
        vm_prefix: 'some-vm-prefix',
        mount_ephemeral_disk: false,
    ).builders }

    let (:expected_baseline) { {
        'type' => 'azure-arm',
        'client_id' => 'some-client-id',
        'client_secret' => 'some-client-secret',
        'tenant_id' => 'some-tenant-id',
        'subscription_id' => 'some-subscription-id',
        'object_id' => 'some-object-id',
        'os_disk_size_gb' => 30,
        'resource_group_name' => 'some-resource-group-name',
        'temp_resource_group_name' => "some-vm-prefix-#{Time.now.to_i}",
        'storage_account' => 'some-storage-account',
        'capture_container_name' => 'packer-stemcells',
        'capture_name_prefix' => 'bosh-stemcell',
        'image_publisher' => 'MicrosoftWindowsServer',
        'image_offer' => 'some-base-image-offer',
        'image_sku' => 'some-base-image',
        'location' => 'some-location',
        'vm_size' => 'some-vm-size',
        'os_type' => 'Windows',
        'communicator' => 'winrm',
        'winrm_use_ssl' => 'true',
        'winrm_insecure' => 'true',
        'winrm_timeout' => '1h',
        'winrm_username' => 'packer'
    } }

    context 'all os versions' do
      let(:os) { '' }

      it 'returns the expected builders' do
        expect(builders[0]).to include(expected_baseline)
      end
    end

    context 'windows2012R2' do
      let(:os) { 'windows2012R2' }

      it 'returns the expected builders with a 128GB root disk' do
        expect(builders[0]).to include(expected_baseline.merge({ 'os_disk_size_gb' => 128 }))
      end
    end

    context 'when vm_prefix is empty' do
      it 'defaults to packer' do
        builders = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          object_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: '',
          os: '',
          vm_prefix: ''
        ).builders
        expect(builders[0]).to include(
          'temp_resource_group_name' => "packer-#{Time.now.to_i}"
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
        provisioners = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          object_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: 'some-output-directory',
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip'"]},
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS azure"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end
    end

    context 'windows 2016' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          object_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: 'some-output-directory',
          os: 'windows2016',
          vm_prefix: '',
          mount_ephemeral_disk: false,
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                             'trap { $host.SetShouldExit(1) }',
                                             'Clear-ProxySettings']},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS azure"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end

      context 'when provisioning with emphemeral disk mounting enabled' do
        it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
          allow(SecureRandom).to receive(:hex).and_return("some-password")
          provisioners = Packer::Config::Azure.new(
            client_id: '',
            client_secret: '',
            tenant_id: '',
            subscription_id: '',
            object_id: '',
            resource_group_name: '',
            storage_account: '',
            location: '',
            vm_size: '',
            output_directory: 'some-output-directory',
            os: 'windows2016',
            vm_prefix: '',
            mount_ephemeral_disk: true,
           ).provisioners

          expect(provisioners).to include(
            {
              "type"=>"powershell",
              "inline"=>[
                "$ErrorActionPreference = \"Stop\";",
                "trap { $host.SetShouldExit(1) }",
                "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
              ]
            }
          )
        end
      end
    end

    context 'windows 1803' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          object_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: 'some-output-directory',
          os: 'windows1803',
          vm_prefix: '',
          mount_ephemeral_disk: false,
        ).provisioners
        expected_provisioners_except_lgpo = [
          {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip"},
          {"type" => "powershell", "scripts" => ["scripts/install-bosh-psmodules.ps1"]},
          {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            'Set-ProxySettings ']},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Remove-DockerPackage", "restart_timeout"=>"1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
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
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            'Clear-ProxySettings']},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS azure"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end

      context 'when provisioning with emphemeral disk mounting enabled' do
        it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
          allow(SecureRandom).to receive(:hex).and_return("some-password")
          provisioners = Packer::Config::Azure.new(
            client_id: '',
            client_secret: '',
            tenant_id: '',
            subscription_id: '',
            object_id: '',
            resource_group_name: '',
            storage_account: '',
            location: '',
            vm_size: '',
            output_directory: 'some-output-directory',
            os: 'windows1803',
            vm_prefix: '',
            mount_ephemeral_disk: true,
          ).provisioners

          expect(provisioners).to include(
            {
              "type" => "powershell",
              "inline" => [
                "$ErrorActionPreference = \"Stop\";",
                "trap { $host.SetShouldExit(1) }",
                "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
              ]
            }
          )
        end
      end
    end
  end
end
