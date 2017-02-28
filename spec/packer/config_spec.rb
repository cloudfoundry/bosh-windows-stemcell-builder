require 'packer/config'

describe Packer::Config do
  describe 'Aws' do
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
                                           regions).builders
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
          'user_data_file' => 'scripts/aws/setup_winrm.txt',
          'security_group_id' => 'sg1',
          'ami_groups' => 'all'
        )
        expect(builders[0]['ami_name']).to match(/BOSH-.*-region1/)
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        provisioners = Packer::Config::Aws.new('', '', []).provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::SET_EC2_PASSWORD,
            Packer::Config::Provisioners::SETUP_AGENT,
            Packer::Config::Provisioners::AWS_AGENT_CONFIG,
            Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
            Packer::Config::Provisioners::DISABLE_SERVICES,
            Packer::Config::Provisioners::SET_FIREWALL,
            Packer::Config::Provisioners::CLEANUP_ARTIFACTS
          ]
        )
      end
    end

    describe 'dump' do
      it 'outputs a valid packer json config' do
        pending('packer validate actually requires files to exist')
        fail

        regions = [
          {
            'name' => 'us-east-1',
            'ami_name' => 'ami1',
            'base_ami' => 'baseami1',
            'vpc_id' => 'vpc1',
            'subnet_id' => 'subnet1',
            'security_group' => 'sg1'
          }
        ]
        config = Packer::Config::Aws.new('accesskey',
                                         'secretkey',
                                         regions).dump
        puts config
        runner = Packer::Runner.new(config)
        success = runner.run('validate', {})
        expect(success).to be(true)
      end
    end
  end

  describe 'Gcp' do
    describe 'builders' do
      it 'returns the expected builders' do
        account_json = 'some-account-json'
        project_id = 'some-project-id'
        source_image = 'some-base-image'
        builders = Packer::Config::Gcp.new(account_json, project_id, source_image).builders
        expect(builders[0]).to include(
          'type' => 'googlecompute',
          'account_file' => account_json,
          'project_id' => project_id,
          'tags' => ['winrm'],
          'source_image' => source_image,
          'image_family' => 'windows-2012-r2',
          'zone' => 'us-east1-c',
          'disk_size' => 50,
          'machine_type' => 'n1-standard-4',
          'omit_external_ip' => false,
          'communicator' => 'winrm',
          'winrm_username' => 'winrmuser',
          'winrm_use_ssl' => false,
          'metadata' => {
            'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/gcp-setup-winrm.ps1'
          }
        )
        expect(builders[0]['image_name']).to match(/packer-\d+/)
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json).provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::WINRM_CONFIG,
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::SETUP_AGENT,
            Packer::Config::Provisioners::GCP_AGENT_CONFIG,
            Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
            Packer::Config::Provisioners::DISABLE_SERVICES,
            Packer::Config::Provisioners::SET_FIREWALL,
            Packer::Config::Provisioners::CLEANUP_ARTIFACTS
          ]
        )
      end
    end
  end

  describe 'VSphere' do
    describe 'builders' do
      it 'returns the expected builders' do
        pending('vSphere builder being transitioned to VMX')
        fail

        builders = Packer::Config::VSphere.new('isourl', 'isochecksum',
                                               'winrmhost', 'password', 1, 1).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-iso',
          'iso_url' => 'isourl',
          'iso_checksum_type' => 'md5',
          'iso_checksum' => 'isochecksum',
          'headless' => false,
          'boot_wait' => '2m',
          'communicator' => 'winrm',
          'winrm_username' => 'Administrator',
          'winrm_password' => 'vagrant',
          'winrm_timeout' => '72h',
          'winrm_insecure' => true,
          'winrm_host' => 'winrmhost',
          'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File a =>\\sysprep.ps1 -NewPassword password',
          'shutdown_timeout' => '1h',
          'guest_os_type' => 'windows8srv-64',
          'tools_upload_flavor' => 'windows',
          'disk_size' => 40000,
          'vnc_port_min' => 5900,
          'vnc_port_max' => 5980,
          'floppy_files' => [
            'answer_files/2012_r2/Autounattend.xml',
            'scripts/compile-dotnet-assemblies.bat',
            'scripts/setup-network-interface.ps1',
            'scripts/microsoft-updates.bat',
            'scripts/updates.ps1',
            'scripts/initial-setup.ps1',
            'scripts/sysprep.ps1',
            'policy-baseline.zip',
            'network-interface-settings.xml',
            'scripts/install-ps-windows-update-module.ps1',
            '../../windows-stemcell-dependencies/ps-windowsupdate/PSWindowsUpdate.zip'
          ],
          'vmx_data' => {
            'memsize' => '1',
            'numvcpus' => '1',
            'scsi0.virtualDev' => 'lsisas1068',
            'ethernet0.present' => 'TRUE',
            'ethernet0.startConnected' => 'TRUE',
            'ethernet0.virtualDev' => 'e1000',
            'ethernet0.networkName' => 'VM Network',
            'ethernet0.addressType' => 'generated',
            'ethernet0.generatedAddressOffset' => '0',
            'ethernet0.wakeOnPcktRcv' => 'FALSE'
          },
          'output_directory' => 'output-vmware-iso',
          'format' => 'vmx'
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        pending('vSphere builder being transitioned to VMX')
        fail

        provisioners = Packer::Config::VSphere.new('', '', '', '', 1, 1).provisioners
        expect(provisioners).to eq(
          [
          ]
        )
      end
    end
  end

  describe 'Azure' do
    describe 'builders' do
      it 'returns the expected builders' do
        pending('not yet implemented')
        fail
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        pending('not yet implemented')
        fail
      end
    end
  end

  describe 'OpenStack' do
    describe 'builders' do
      it 'returns the expected builders' do
        pending('not yet implemented')
        fail
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        pending('not yet implemented')
        fail
      end
    end
  end
end
