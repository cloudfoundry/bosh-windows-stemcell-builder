require 'securerandom'

module Packer
  module Config
    class VSphereBase < Base
      def initialize(administrator_password:, source_path:, output_directory:,
                     mem_size:, num_vcpus:, os:)
        @administrator_password = administrator_password
        @source_path = source_path
        @output_directory = output_directory
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @timestamp = Time.now.getutc.to_i
        @os = os
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
            'winrm_timeout' => '6h',
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
          Provisioners::BOSH_PSMODULES,
          Provisioners::NEW_PROVISIONER,
          Provisioners.install_windows_updates,
          Provisioners::GET_LOG,
          Provisioners::CLEAR_PROVISIONER
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
          'shutdown_command' => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword #{@administrator_password} -ProductKey #{@product_key} -Owner #{@owner} -Organization #{@organization}",
          'shutdown_timeout' => '1h',
          'communicator' => 'winrm',
          'ssh_username' => 'Administrator',
          'winrm_username' => 'Administrator',
          'winrm_password' => @administrator_password,
          'winrm_timeout' => '1h',
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
          Base.pre_provisioners(@os),
          Provisioners::lgpo_exe,
          Provisioners.install_agent('vsphere').freeze,
          Provisioners.download_windows_updates(@output_directory).freeze,
          Base.post_provisioners('vsphere')
        ].flatten
      end
    end
  end
end
