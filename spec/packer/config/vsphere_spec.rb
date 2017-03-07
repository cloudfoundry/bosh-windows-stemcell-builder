require 'packer/config'

describe Packer::Config do
  describe 'VSphereAddUpdates' do
    describe 'builders' do
      it 'returns the expected builders' do
        builders = Packer::Config::VSphereAddUpdates.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          administrator_password: 'password',
          source_path: 'source_path'
        ).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-vmx',
          'source_path' => 'source_path',
          'headless' => false,
          'boot_wait' => '2m',
          'communicator' => 'winrm',
          'winrm_username' => 'Administrator',
          'winrm_password' => 'password',
          'winrm_timeout' => '5m',
          'winrm_insecure' => true,
          'vm_name' => 'packer-vmx',
          'shutdown_command' => "C:\\Windows\\System32\\shutdown.exe /s",
          'shutdown_timeout' => '1h',
          'vmx_data' => {
            'memsize' => '1000',
            'numvcpus' => '1'
          },
          'output_directory' => 'output_directory'
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do

        provisioners = Packer::Config::VSphereAddUpdates.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          administrator_password: 'password',
          source_path: 'source_path'
        ).provisioners

        restart_provisioner = Packer::Config::Provisioners::VMX_WINDOWS_RESTART
        restart_provisioner['restart_command'] = restart_provisioner['restart_command'].sub!('ADMINISTRATOR_PASSWORD', 'password')

        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::CREATE_PROVISION_DIR,
            Packer::Config::Provisioners::VMX_UPDATE_PROVISIONER,
            Packer::Config::Provisioners::VMX_AUTORUN_UPDATES,
            Packer::Config::Provisioners::VMX_POWERSHELLUTILS,
            Packer::Config::Provisioners::VMX_PSWINDOWSUPDATE,
            restart_provisioner, # Required because we need to set the admin password
            Packer::Config::Provisioners::VMX_READ_UPDATE_LOG
          ]
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
          source_path: 'source_path'
        ).builders
        expect(builders[0]).to eq(
          'type' => 'vmware-vmx',
          'source_path' => 'source_path',
          'headless' => false,
          'boot_wait' => '2m',
          'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File C:\\sysprep.ps1 -NewPassword password -ProductKey key -Owner me -Organization me',
          'shutdown_timeout' => '1h',
          'communicator' => 'winrm',
          'ssh_username' => 'Administrator',
          'winrm_username' => 'Administrator',
          'winrm_password' => 'password',
          'winrm_timeout' => '8m',
          'winrm_insecure' => true,
          'vm_name' => 'packer-vmx',
          'vmx_data' => {
            'memsize' => '1000',
            'numvcpus' => '1'
          },
          'output_directory' => 'output_directory'
        )
      end
    end

    describe 'provisioners' do
      it 'returns the expected provisioners' do
        provisioners = Packer::Config::VSphere.new(
          output_directory: 'output_directory',
          num_vcpus: 1,
          mem_size: 1000,
          product_key: 'key',
          organization: 'me',
          owner: 'me',
          administrator_password: 'password',
          source_path: 'source_path'
        ).provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::AGENT_ZIP,
            Packer::Config::Provisioners::AGENT_DEPS_ZIP,
            Packer::Config::Provisioners::POLICY_BASELINE_ZIP,
            Packer::Config::Provisioners::LGPO_EXE,
            Packer::Config::Provisioners::VMX_STEMCELL_SYSPREP,
            Packer::Config::Provisioners::ENABLE_RDP,
            Packer::Config::Provisioners::CHECK_UPDATES,
            Packer::Config::Provisioners::ADD_VCAP_GROUP,
            Packer::Config::Provisioners::RUN_POLICIES,
            Packer::Config::Provisioners::SETUP_AGENT,
            Packer::Config::Provisioners::VSPHERE_AGENT_CONFIG,
            Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
            Packer::Config::Provisioners::DISABLE_SERVICES,
            Packer::Config::Provisioners::SET_FIREWALL,
            Packer::Config::Provisioners::CLEANUP_TEMP_DIRS,
            Packer::Config::Provisioners::CLEANUP_ARTIFACTS
          ]
        )
      end
    end
  end
end
