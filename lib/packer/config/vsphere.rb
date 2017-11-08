require 'securerandom'

module Packer
  module Config
    class VSphereBase < Base
      def initialize(administrator_password:,
                     source_path:,
                     output_directory:,
                     mem_size:,
                     num_vcpus:,
                     os:,
                     skip_windows_update:false)
        @administrator_password = administrator_password
        @source_path = source_path
        @output_directory = output_directory
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @timestamp = Time.now.getutc.to_i
        @os = os
        @skip_windows_update = skip_windows_update
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
        pre = [
          Provisioners::BOSH_PSMODULES,
          Provisioners::NEW_PROVISIONER
        ]
        windows_updates = @skip_windows_update?[]:[Provisioners.install_windows_updates]
        post = [
          Provisioners::GET_LOG,
          Provisioners::CLEAR_PROVISIONER,
          Provisioners::WAIT_AND_RESTART,
          Provisioners::WAIT_AND_RESTART
        ]

        (pre + windows_updates + post).flatten
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:,
                     owner:,
                     organization:,
                     enable_rdp:,
                     enable_kms:,
                     kms_host:,
                     new_password:,
                     **args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        @enable_rdp = enable_rdp
        @enable_kms = enable_kms
        @kms_host = kms_host
        @new_password = new_password
        super(args)
      end

      def builders
        enable_rdp = @enable_rdp ? ' -EnableRdp' : ''
        product_key_flag = @product_key.to_s.empty? ? '' : " -ProductKey #{@product_key}"
        [
          'type' => 'vmware-vmx',
          'source_path' => @source_path,
          'headless' => false,
          'boot_wait' => '2m',
          'shutdown_command' => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword #{@new_password}#{product_key_flag} -Owner #{@owner} -Organization #{@organization}#{enable_rdp}",
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
        pre = [
          Base.pre_provisioners(@os, skip_windows_update: @skip_windows_update),
          Provisioners::lgpo_exe,
          Provisioners.install_agent('vsphere').freeze,
        ]
        download_windows_updates = (@skip_windows_update || @os != 'windows2012R2')?[]:[Provisioners.download_windows_updates(@output_directory).freeze]

        setup_kms_server = []
        if @enable_kms && !@kms_host.nil? && !@kms_host.empty?
          setup_kms_server << Provisioners.setup_kms_server(@kms_host)
        end

        post = [Base.post_provisioners('vsphere')]

        (pre + download_windows_updates + post + setup_kms_server).flatten
      end
    end
  end
end
