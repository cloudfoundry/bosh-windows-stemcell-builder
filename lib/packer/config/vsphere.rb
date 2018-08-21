require 'securerandom'

module Packer
  module Config
    class VSphereBase < Base
      def initialize(administrator_password:,
                     source_path:,
                     mem_size:,
                     num_vcpus:,
                     skip_windows_update:false,
                     http_proxy:,
                     https_proxy:,
                     bypass_list:,
                    **args)
        @administrator_password = administrator_password
        @source_path = source_path
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @timestamp = Time.now.getutc.to_i
        @skip_windows_update = skip_windows_update
        @http_proxy = http_proxy
        @https_proxy = https_proxy
        @bypass_list = bypass_list
        super(args)
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
          Provisioners.setup_proxy_settings(@http_proxy, @https_proxy, @bypass_list),
          @skip_windows_update ? [] : [Provisioners.install_windows_updates],
          Provisioners::GET_LOG,
          Provisioners::CLEAR_PROXY_SETTINGS,
          Provisioners::CLEAR_PROVISIONER,
          Provisioners::WAIT_AND_RESTART,
          Provisioners::WAIT_AND_RESTART
        ].flatten
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:,
                     owner:,
                     organization:,
                     enable_rdp:,
                     new_password:,
                     **args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        @enable_rdp = enable_rdp
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
          'shutdown_command' => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -OsVersion #{@os} -NewPassword #{@new_password}#{product_key_flag} -Owner #{@owner} -Organization #{@organization}#{enable_rdp}",
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
        install_manual_updates = []
        if @os == "windows2016" || @os == 'windows1803'
          install_manual_updates <<  Provisioners::INSTALL_KB2538243
        end
        pre = [
            Base.pre_provisioners(@os, skip_windows_update: @skip_windows_update, http_proxy: @http_proxy, https_proxy: @https_proxy, bypass_list: @bypass_list),
            @skip_windows_update ? [] : install_manual_updates,
            Provisioners::lgpo_exe,
            Provisioners.install_agent('vsphere', @mount_ephemeral_disk).freeze,
        ]
        download_windows_updates = @skip_windows_update?[]:[Provisioners.download_windows_updates(@output_directory).freeze]

        patches = [Base.enable_security_patches(@os)]
        post = [Base.post_provisioners('vsphere', @os)]

        [pre,
         download_windows_updates,
         patches,
         post].flatten
      end
    end
  end
end
