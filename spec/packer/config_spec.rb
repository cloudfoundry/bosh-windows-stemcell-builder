require 'packer/config'

describe Packer::Config do
  describe 'Base' do
    describe 'dump' do
      it 'returns a json string combining the builders and provisioners' do
        config = Packer::Config::Base.new.dump
        expect(JSON.parse(config)).to eq(
          'builders' => [],
          'provisioners' => [
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::COMMON_POWERSHELL
          ]
        )
      end
    end
  end

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
                                           'aminame1',
                                           regions).builders
        expect(builders[0]).to eq(
          'name' => 'amazon-ebs-region1',
          'type' => 'amazon-ebs',
          'access_key' => 'accesskey',
          'secret_key' => 'secretkey',
          'region' => 'region1',
          'source_ami' => 'baseami1',
          'instance_type' => 'm4.xlarge',
          'ami_name' => 'aminame1-region1',
          'vpc_id' => 'vpc1',
          'subnet_id' => 'subnet1',
          'associate_public_ip_address' => true,
          'communicator' => 'winrm',
          'winrm_username' => 'Administrator',
          'user_data_file' => 'setup_winrm.txt',
          'security_group_id' => 'sg1',
          'ami_groups' => 'all'
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        provisioners = Packer::Config::Aws.new('', '', '', []).provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::SET_EC2_PASSWORD,
            Packer::Config::Provisioners::COMMON_POWERSHELL
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
                                         'aminame1',
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
        builders = Packer::Config::Gcp.new('accountjson',
                                           'projectid',
                                           'imageid').builders
        expect(builders[0]).to eq(
          'type' => 'googlecompute',
          'account_file' => 'accountjson',
          'project_id' => 'projectid',
          'tags' => ['winrm'],
          'source_image' => 'windows-2012-r2-winrm',
          'image_family' => 'windows-2012-r2',
          'zone' => 'us-east1-c',
          'disk_size' => 50,
          'image_name' =>  'imageid',
          'machine_type' => 'n1-standard-4',
          'omit_external_ip' => false,
          'communicator' => 'winrm',
          'winrm_username' => 'winrmuser',
          'winrm_use_ssl' => false
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        provisioners = Packer::Config::Gcp.new('', '', '').provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::WINRM_CONFIG,
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::COMMON_POWERSHELL
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
            Packer::Config::Provisioners::WINDOWS_RESTART,
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::INSTALL_WINDOWS_FEATURES,
            Packer::Config::Provisioners::LGPO_EXE,
            Packer::Config::Provisioners::VMWARE_TOOLS_EXE,
            Packer::Config::Provisioners::INSTALL_VMWARE_TOOLS,
            Packer::Config::Provisioners::ENABLE_RDP,
            Packer::Config::Provisioners::DISABLE_AUTO_LOGON,
            Packer::Config::Provisioners::ADD_VCAP_GROUP,
            Packer::Config::Provisioners::RUN_LGPO,
            Packer::Config::Provisioners::COMMON_POWERSHELL,
            Packer::Config::Provisioners::CLEANUP_TEMP_DIRS,
            Packer::Config::Provisioners::COMPACT_DISK
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
