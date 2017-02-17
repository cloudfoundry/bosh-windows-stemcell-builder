require 'securerandom'

module Packer
  module Config
    class VSphere < Base
      def initialize(iso_url, iso_checksum, winrm_host, admin_password,
                     mem_size, num_vcpus)
        @iso_url = iso_url
        @iso_checksum = iso_checksum
        @winrm_host = winrm_host
        @admin_password = admin_password
        @mem_size = mem_size
        @num_vcpus = num_vcpus
      end

      def builders
        [
          {
            'type' => 'vmware-iso',
            'iso_url' => @iso_url,
            'iso_checksum_type' => 'md5',
            'iso_checksum' => @iso_checksum,
            'headless' => false,
            'boot_wait' => '2m',
            'communicator' => 'winrm',
            'winrm_username' => 'Administrator',
            'winrm_password' => 'vagrant',
            'winrm_timeout' => '72h',
            'winrm_insecure' => true,
            'winrm_host' => @winrm_host,
            'shutdown_command' => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File a =>\\sysprep.ps1 -NewPassword #{@admin_password}",
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
              'memsize' => @mem_size.to_s,
              'numvcpus' => @num_vcpus.to_s,
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
          }
        ]
      end

      def provisioners
        []
      end
    end
  end
end
