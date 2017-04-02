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
        @timestamp = Time.now.getutc.to_i
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
              'numvcpus' => @num_vcpus.to_s,
              'displayname' => "packer-vmx-#{@timestamp}"
            },
            'output_directory' => @output_directory
          }
        ]
      end

      def provisioners
        [
          Provisioners::NEW_PROVISIONER,
          Provisioners::BOSH_PSMODULES,
          Provisioners.install_windows_updates(@administrator_password).freeze,
          Provisioners::GET_LOG
        ].flatten
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
            'numvcpus' => @num_vcpus.to_s,
            'displayname' => "packer-vmx-#{@timestamp}"
          },
          'output_directory' => @output_directory,
          'skip_clean_files' => true
        ]
      end

      def provisioners
        [
          Provisioners::NEW_PROVISIONER,
          Provisioners::BOSH_PSMODULES,
          Provisioners::LGPO_EXE,
          Provisioners::VMX_STEMCELL_SYSPREP,
          Provisioners::ENABLE_RDP,
          Provisioners::ADD_VCAP_GROUP,
          Provisioners::RUN_POLICIES,
          Provisioners.install_agent('vsphere').freeze,
          Provisioners::INSTALL_CF_FEATURES,
          Provisioners::CLEANUP_WINDOWS_FEATURES,
          Provisioners.download_windows_updates(@output_directory).freeze,
          Provisioners::DISABLE_SERVICES,
          Provisioners::SET_FIREWALL,
          Provisioners::CLEANUP_TEMP_DIRS,
          Provisioners::CLEANUP_ARTIFACTS,
          Provisioners::COMPRESS_DISK
        ].flatten
      end
    end
  end
end
