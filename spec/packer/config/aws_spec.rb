require 'packer/config'
require 'timecop'

describe Packer::Config::Aws do
  describe 'builders' do
    before :each do
      Timecop.freeze
    end

    after :each do
      Timecop.return
    end

    let(:region) do
      {
        name: 'region1',
        base_ami: 'baseami1',
        vpc_id: 'vpc1',
        subnet_id: 'subnet1',
        security_group: 'sg1'
      }
    end

    let(:builders) do
      Packer::Config::Aws.new(
        aws_access_key: 'some-aws-access-key',
        aws_secret_key: 'some-aws-secret-key',
        region: region,
        output_directory: 'some-output-directory',
        os: os,
        vm_prefix: 'some-vm-prefix'
      ).builders
    end

    let(:baseline_builders) do
      {
        name: 'amazon-ebs-region1',
        type: 'amazon-ebs',
        access_key: 'some-aws-access-key',
        secret_key: 'some-aws-secret-key',
        region: 'region1',
        source_ami: 'baseami1',
        instance_type: 'm5.large',
        vpc_id: 'vpc1',
        subnet_id: 'subnet1',
        associate_public_ip_address: true,
        launch_block_device_mappings: [
          {
            'device_name': '/dev/sda1',
            'volume_size': 30,
            'volume_type': 'gp2',
            'delete_on_termination': true,
          }
        ],
        communicator: 'winrm',
        winrm_username: 'Administrator',
        winrm_timeout: '1h',
        user_data_file: 'scripts/aws/setup_winrm.txt',
        security_group_id: 'sg1',
        ami_groups: 'all',
        run_tags: { Name: "some-vm-prefix-#{Time.now.to_i}" }
      }
    end

    context 'all OSs' do
      let(:os) { '' }

      it 'returns the baseline builders' do
        expect(builders[0]).to include(baseline_builders)
        expect(builders[0][:ami_name]).to match(/BOSH-.*-region1/)
      end
    end

    context 'windows2012R2' do
      let(:os) { 'windows2012R2' }

      it 'returns the expected builders with a 128GB root disk' do
        expect(builders[0]).to include(baseline_builders.merge({
                                                                   instance_type: 'm4.xlarge',
                                                                   launch_block_device_mappings: [
                                                                       {
                                                                           device_name: '/dev/sda1',
                                                                           volume_size: 128,
                                                                           volume_type: 'gp2',
                                                                           delete_on_termination: true,
                                                                       }
                                                                   ],
                                                               }))
      end
    end

    context 'when vm_prefix is empty' do
      it 'defaults to packer' do
        builders = Packer::Config::Aws.new(
          aws_access_key: '',
          aws_secret_key: '',
          region: region,
          output_directory: '',
          os: '',
          vm_prefix: ''
        ).builders
        expect(builders[0]).to include(
          run_tags: { Name: "packer-#{Time.now.to_i}" }
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
        provisioners = Packer::Config::Aws.new(
          aws_access_key: '',
          aws_secret_key: '',
          region: '',
          output_directory: 'some-output-directory',
          os: 'windows2012R2',
          vm_prefix: '',
          mount_ephemeral_disk: false
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip'"]},
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
          {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS aws"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)
      end
    end

    context 'windows 2016' do
      it 'returns the expected provisioners' do
        stemcell_deps_dir = Dir.mktmpdir('aws')
        ENV['STEMCELL_DEPS_DIR'] = stemcell_deps_dir

        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Aws.new(
          aws_access_key: '',
          aws_secret_key: '',
          region: '',
          output_directory: 'some-output-directory',
          os: 'windows2016',
          vm_prefix: '',
        ).provisioners
        expected_provisioners_except_lgpo = [
          {"type"=>"file", "source"=>"build/bosh-psmodules.zip", "destination"=>"C:\\provision\\bosh-psmodules.zip"},
          {"type"=>"powershell", "scripts"=>["scripts/install-bosh-psmodules.ps1"]},
          {'type'=>'powershell', 'inline'=>['$ErrorActionPreference = "Stop";',
                                            'trap { $host.SetShouldExit(1) }',
                                            'Set-ProxySettings ']},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Remove-DockerPackage", "restart_timeout"=>"1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"windows-restart", "restart_command"=>"powershell.exe -Command Install-CFFeatures", "restart_timeout"=>"1h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
          {"type"=>"windows-restart", "restart_command"=> "powershell.exe -Command Wait-WindowsUpdates -Password some-password! -User Provisioner", "restart_timeout"=>"12h", "restart_check_command"=> "powershell -command \"& {Write-Output 'restarted.'}\""},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
          {"type"=>"file", "source"=>"../sshd/OpenSSH-Win64.zip", "destination"=>"C:\\provision\\OpenSSH-Win64.zip"},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
          {"type"=>"file", "source"=>"build/agent.zip", "destination"=>"C:\\provision\\agent.zip"},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type'=>'powershell', 'inline'=> ['$ErrorActionPreference = "Stop";',
                                             'trap { $host.SetShouldExit(1) }',
                                             'Clear-ProxySettings']},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS aws"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)

        FileUtils.rm_rf(stemcell_deps_dir)
        ENV.delete('STEMCELL_DEPS_DIR')
      end

      context 'when provisioning with emphemeral disk mounting enabled' do
        it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
          allow(SecureRandom).to receive(:hex).and_return("some-password")
          provisioners = Packer::Config::Aws.new(
            aws_access_key: '',
            aws_secret_key: '',
            region: '',
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
                "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
              ]
            }
          )
        end
      end
    end

    context 'windows 1803' do
      it 'returns the expected provisioners' do
        stemcell_deps_dir = Dir.mktmpdir('aws')
        ENV['STEMCELL_DEPS_DIR'] = stemcell_deps_dir

        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Aws.new(
          aws_access_key: '',
          aws_secret_key: '',
          region: '',
          output_directory: 'some-output-directory',
          os: 'windows1803',
          vm_prefix: '',
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
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip'"]},
          {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            'Clear-ProxySettings']},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
          {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Invoke-Sysprep -IaaS aws"]}
        ].flatten
        expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil
        provisioners_no_lgpo = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
        expect(provisioners_no_lgpo).to eq (expected_provisioners_except_lgpo)

        FileUtils.rm_rf(stemcell_deps_dir)
        ENV.delete('STEMCELL_DEPS_DIR')
      end

      context 'when provisioning with emphemeral disk mounting enabled' do
        it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
          allow(SecureRandom).to receive(:hex).and_return("some-password")
          provisioners = Packer::Config::Aws.new(
            aws_access_key: '',
            aws_secret_key: '',
            region: '',
            output_directory: 'some-output-directory',
            os: 'windows2016',
            vm_prefix: '',
            mount_ephemeral_disk: true,
          ).provisioners

          expect(provisioners).to include(
            {
              "type" => "powershell",
              "inline" => [
                "$ErrorActionPreference = \"Stop\";",
                "trap { $host.SetShouldExit(1) }",
                "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
              ]
            }
          )
        end
      end
    end
  end
end
