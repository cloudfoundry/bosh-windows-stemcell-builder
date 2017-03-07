require 'securerandom'

module Packer
  module Config
    class VSphereBase < Base
      def initialize(administrator_password:, source_path:, output_directory:,
                     mem_size:, num_vcpus:)
        @administrator_password = administrator_password
        @source_path = source_path
        @output_directory = output_directory
        @mem_size = mem_size
        @num_vcpus = num_vcpus
      end
    end


    class VSphereAddUpdates < VSphereBase
      def builders
        [
          {
            'type' => 'vmware-vmx',
            'source_path' => @source_path,
            'headless' => false,
            'boot_wait' => '2m',
            'communicator' => 'winrm',
            'winrm_username' => 'Administrator',
            'winrm_password' => @administrator_password,
            'winrm_timeout' => '5m',
            'winrm_insecure' => true,
            'vm_name' =>  'packer-vmx',
            'shutdown_command' => "C:\\Windows\\System32\\shutdown.exe /s",
            'shutdown_timeout' => '1h',
            'vmx_data' => {
              'memsize' => @mem_size.to_s,
              'numvcpus' => @num_vcpus.to_s
            },
            'output_directory' => @output_directory
          }
        ]
      end

      def provisioners
        # clone because we modify it
        restart_provisioner = Provisioners::VMX_WINDOWS_RESTART.clone

        command = restart_provisioner['restart_command']
        if !command.nil? && !command.index('ADMINISTRATOR_PASSWORD').nil?
          restart_provisioner['restart_command'] = command.sub('ADMINISTRATOR_PASSWORD', @administrator_password)
        end

        [
          Provisioners::CREATE_PROVISION_DIR,
          Provisioners::VMX_UPDATE_PROVISIONER,
          Provisioners::VMX_AUTORUN_UPDATES,
          Provisioners::VMX_POWERSHELLUTILS,
          Provisioners::VMX_PSWINDOWSUPDATE,
          restart_provisioner,
          Provisioners::VMX_READ_UPDATE_LOG
        ]
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:,owner:,organization:,**args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        super(args)
      end
      def builders
        [
          'type' => 'vmware-vmx',
          'source_path' => @source_path,
          'headless' => false,
          'boot_wait' => '2m',
          'shutdown_command' => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File C:\\sysprep.ps1 -NewPassword #{@administrator_password} -ProductKey #{@product_key} -Owner #{@owner} -Organization #{@organization}",
          'shutdown_timeout' => '1h',
          'communicator' => 'winrm',
          'ssh_username' => 'Administrator',
          'winrm_username' => 'Administrator',
          'winrm_password' => @administrator_password,
          'winrm_timeout' => '8m',
          'winrm_insecure' => true,
          'vm_name' =>  'packer-vmx',
          'vmx_data' => {
            'memsize' => @mem_size.to_s,
            'numvcpus' => @num_vcpus.to_s
          },
          'output_directory' => @output_directory
        ]
      end

      def provisioners
        [
          Provisioners::AGENT_ZIP,
          Provisioners::AGENT_DEPS_ZIP,
          Provisioners::POLICY_BASELINE_ZIP,
          Provisioners::LGPO_EXE,
          Provisioners::VMX_STEMCELL_SYSPREP,
          Provisioners::ENABLE_RDP,
          Provisioners::CHECK_UPDATES,
          Provisioners::ADD_VCAP_GROUP,
          Provisioners::RUN_POLICIES,
          Provisioners::SETUP_AGENT,
          Provisioners::VSPHERE_AGENT_CONFIG,
          Provisioners::CLEANUP_WINDOWS_FEATURES,
          Provisioners::DISABLE_SERVICES,
          Provisioners::SET_FIREWALL,
          Provisioners::CLEANUP_TEMP_DIRS,
          Provisioners::CLEANUP_ARTIFACTS
        ]
      end
    end
  end
end
