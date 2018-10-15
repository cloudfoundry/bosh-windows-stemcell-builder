require 'securerandom'

module Packer
  module Config
    class VSphereBase
      def initialize(administrator_password:, source_path:, mem_size:, num_vcpus:, skip_windows_update: false, http_proxy:, https_proxy:, bypass_list:, os:, output_directory:, vm_prefix: '', mount_ephemeral_disk: false)
        @administrator_password = administrator_password
        @source_path = source_path
        @mem_size = mem_size
        @num_vcpus = num_vcpus
        @timestamp = Time.now.getutc.to_i
        @skip_windows_update = skip_windows_update
        @http_proxy = http_proxy
        @https_proxy = https_proxy
        @bypass_list = bypass_list
        @os = os
        @output_directory = output_directory
        @vm_prefix = vm_prefix.empty? ? 'packer' : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
      end

      def dump
        JSON.dump(
            'builders' => builders,
            'provisioners' => provisioners
        )
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
                'vm_name' => 'packer-vmx',
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
        ProvisionerFactory.new("#{@os}_vsphere_updates", 'update-vsphere', @mount_ephemeral_disk, @http_proxy, @https_proxy, @bypass_list).dump
      end
    end

    class VSphere < VSphereBase
      def initialize(product_key:,
                     owner:,
                     organization:,
                     enable_rdp:,
                     new_password:,
                     build_context: :stemcell,
                     **args)
        @product_key = product_key
        @owner = owner
        @organization = organization
        @enable_rdp = enable_rdp
        @new_password = new_password
        @build_context = build_context
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
            'vm_name' => 'packer-vmx',
            'vmx_data' => {
                'memsize' => @mem_size.to_s,
                'numvcpus' => @num_vcpus.to_s,
                'displayname' => "packer-vmx-#{@timestamp}"
            },
            'output_directory' => @output_directory,
        ]
      end

      def provisioners
        ProvisionerFactory.new(@os, 'vsphere', @mount_ephemeral_disk, @http_proxy, @https_proxy, @bypass_list, @build_context).dump
      end
    end
  end
end
