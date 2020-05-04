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
        resource_group_name: 'some-resource-group-name',
        storage_account: 'some-storage-account',
        location: 'some-location',
        vm_size: 'some-vm-size',
        output_directory: '',
        os: os,
        version: '',
        vm_prefix: 'some-vm-prefix',
        mount_ephemeral_disk: false,
    ).builders }

    let (:expected_baseline) { {
        'type' => 'azure-arm',
        'client_id' => 'some-client-id',
        'client_secret' => 'some-client-secret',
        'tenant_id' => 'some-tenant-id',
        'subscription_id' => 'some-subscription-id',
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

    context 'when vm_prefix is empty' do
      it 'defaults to packer' do
        builders = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: '',
          os: '',
          version: '',
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

    context 'windows 2019' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        version = '2019.43.17-build.1'
        provisioners = Packer::Config::Azure.new(
          client_id: '',
          client_secret: '',
          tenant_id: '',
          subscription_id: '',
          resource_group_name: '',
          storage_account: '',
          location: '',
          vm_size: '',
          output_directory: 'some-output-directory',
          os: 'windows2019',
          version: version,
          vm_prefix: '',
          mount_ephemeral_disk: false,
          ).provisioners
        expected_provisioners_base = [
          {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip", "pause_before"=>"60s"},
          {"type"=>"file", "source"=>"scripts/install-bosh-psmodules.ps1", "destination"=>"C:\\provision\\install-bosh-psmodules.ps1", "pause_before"=>"60s"},
          {"type"=>"powershell", "inline"=>['$ErrorActionPreference = "Stop";', 'C:\\provision\\install-bosh-psmodules.ps1'], "pause_before"=>"60s"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-DockerPackage"]},
          {"type" => "windows-restart", "restart_timeout" => "1h", "check_registry" => true},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures2016"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-Hyper-V"]},
          {"type" => "windows-restart", "restart_timeout" => "1h", "check_registry" => true},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Wait-WindowsUpdates -Password some-password! -User Provisioner"]},
          {"type" => "windows-restart", "restart_timeout" => "12h", "check_registry" => true},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-HotFix > hotfixes.log"]},
          {"type" => "file", "source" => "hotfixes.log", "destination" => "hotfixes.log", "direction" => "download"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
          {"type" => "file", "source" => "../sshd/OpenSSH-Win64.zip", "destination" => "C:\\provision\\OpenSSH-Win64.zip"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-SSHD"]},
          {"type" => "file", "source" => "build/agent.zip", "destination" => "C:\\provision\\agent.zip"},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS azure -agentZipPath 'C:\\provision\\agent.zip'"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS11"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-TLS12"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-WUCerts"]},
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-SSHKeys"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Set-InternetExplorerRegistries"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS azure"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil

        expect(provisioners.detect do |p|
          p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")
        end).not_to be_nil, "Expect provisioners to include New-VersionFile"

        line_by_line_provisioners = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        line_by_line_provisioners = line_by_line_provisioners.delete_if {|p| p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")}

        expect(line_by_line_provisioners).to eq (expected_provisioners_base)
      end

      context 'when provisioning with emphemeral disk mounting enabled' do
        it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
          allow(SecureRandom).to receive(:hex).and_return("some-password")
          provisioners = Packer::Config::Azure.new(
            client_id: '',
            client_secret: '',
            tenant_id: '',
            subscription_id: '',
            resource_group_name: '',
            storage_account: '',
            location: '',
            vm_size: '',
            output_directory: 'some-output-directory',
            os: 'windows2019',
            vm_prefix: '',
            version: '',
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
