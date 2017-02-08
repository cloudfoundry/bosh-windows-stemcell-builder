module Packer
  module Config
    class Base
      def builders
        []
      end

      def provisioners
        [
          Provisioners::AGENT_ZIP,
          Provisioners::AGENT_DEPS_ZIP,
          Provisioners::INSTALL_WINDOWS_FEATURES,
          Provisioners::COMMON_POWERSHELL
        ]
      end

      def dump
        JSON.dump(
          'builders' => builders,
          'provisioners' => provisioners
        )
      end
    end

    class Aws < Base
      def initialize(aws_access_key, aws_secret_key, ami_name, regions)
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @ami_name = ami_name
        @regions = regions
      end

      def builders
        builders = []
        @regions.each do |region|
          builders.push(
            'name' => "amazon-ebs-#{region['name']}",
            'type' => 'amazon-ebs',
            'access_key' => @aws_access_key,
            'secret_key' => @aws_secret_key,
            'region' => region['name'],
            'source_ami' => region['base_ami'],
            'instance_type' => 'm4.xlarge',
            'ami_name' => "#{@ami_name}-#{region['name']}",
            'vpc_id' => region['vpc_id'],
            'subnet_id' => region['subnet_id'],
            'associate_public_ip_address' => true,
            'communicator' => 'winrm',
            'winrm_username' => 'Administrator',
            'user_data_file' => 'setup_winrm.txt',
            'security_group_id' => region['security_group'],
            'ami_groups' => 'all'
          )
        end
        builders
      end

      def provisioners
        provisioners = super
        provisioners.insert(-2, Provisioners::SET_EC2_PASSWORD)
        provisioners
      end
    end

    class Gcp < Base
      def initialize(account_json_file, project_id, image_name)
        @account_json_file = account_json_file
        @project_id = project_id
        @image_name = image_name
      end

      def builders
        [
          {
            'type' => 'googlecompute',
            'account_file' => @account_json_file,
            'project_id' => @project_id,
            'tags' => ['winrm'],
            'source_image' => 'windows-2012-r2-winrm',
            'image_family' => 'windows-2012-r2',
            'zone' => 'us-east1-c',
            'disk_size' => 50,
            'image_name' =>  @image_name,
            'machine_type' => 'n1-standard-4',
            'omit_external_ip' => false,
            'communicator' => 'winrm',
            'winrm_username' => 'winrmuser',
            'winrm_use_ssl' => false
          }
        ]
      end

      def provisioners
        provisioners = super
        provisioners.unshift(Provisioners::WINRM_CONFIG)
        provisioners
      end
    end

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
        provisioners = super
        provisioners.unshift(Provisioners::WINDOWS_RESTART)
        provisioners.insert(-2, Provisioners::LGPO_EXE,
                            Provisioners::VMWARE_TOOLS_EXE,
                            Provisioners::INSTALL_VMWARE_TOOLS,
                            Provisioners::ENABLE_RDP,
                            Provisioners::DISABLE_AUTO_LOGON,
                            Provisioners::ADD_VCAP_GROUP,
                            Provisioners::RUN_LGPO)
        provisioners.push(Provisioners::CLEANUP_TEMP_DIRS,
                          Provisioners::COMPACT_DISK)
        provisioners
      end
    end

    class Azure < Base
      def builders
        []
      end

      def provisioners
        []
      end
    end

    class OpenStack < Base
      def builders
        []
      end

      def provisioners
        []
      end
    end

    class Provisioners
      AGENT_ZIP = {
        'type' => 'file',
        'source' => '../../compiled-agent/agent.zip',
        'destination' => 'C:\boshagent.zip'
      }.freeze

      AGENT_DEPS_ZIP = {
        'type' => 'file',
        'source' => '../../compiled-agent/agent-dependencies.zip',
        'destination' => 'C:\boshagent-dependencies.zip'
      }.freeze

      WINRM_CONFIG = {
        'type' => 'powershell',
        'inline' => [
          "winrm set winrm/config/winrs '@{MaxShellsPerUser=\"100\"}'",
          "winrm set winrm/config/winrs '@{MaxConcurrentUsers=\"30\"}'",
          "winrm set winrm/config/winrs '@{MaxProcessesPerShell=\"100\"}'",
          "winrm set winrm/config/winrs '@{MaxMemoryPerShellMB=\"1024\"}'",
          "winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser=\"5000\"}'"
        ]
      }.freeze

      WINDOWS_RESTART = {
        'type' => 'windows-restart',
        'restart_timeout' => '1h'
      }.freeze

      INSTALL_WINDOWS_FEATURES = {
        'type' => 'powershell',
        'scripts' => ['../scripts/install-windows-features.ps1']
      }.freeze

      LGPO_EXE = {
        'type' => 'file',
        'source' => '../../windows-stemcell-dependencies/lgpo/LGPO.exe',
        'destination' => 'C:\\LGPO.exe'
      }.freeze

      VMWARE_TOOLS_EXE = {
        'type' => 'file',
        'source' => '../../windows-stemcell-dependencies/VMware-tools/VMware-tools.exe',
        'destination' => 'C:\\VMWare-tools.exe'
      }.freeze

      INSTALL_VMWARE_TOOLS = {
        'type' => 'powershell',
        'scripts' => ['scripts/vm-guest-tools.ps1']
      }.freeze

      ADD_VCAP_GROUP = {
        'type' => 'powershell',
        'scripts' => ['scripts/add-vcap-group.ps1']
      }.freeze

      ENABLE_RDP = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/enable-rdp.bat']
      }.freeze

      RUN_LGPO = {
        'type' => 'powershell',
        'scripts' => ['scripts/run-lgpo.ps1']
      }.freeze

      DISABLE_AUTO_LOGON = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/disable-auto-logon.bat']
      }.freeze

      SET_EC2_PASSWORD = {
        'type' => 'powershell',
        'scripts' => ['scripts/ec2-set-password.ps1']
      }.freeze

      CLEANUP_TEMP_DIRS = {
        'type' => 'powershell',
        'scripts' => ['scripts/cleanup-temp-directories.ps1']
      }.freeze

      COMPACT_DISK = {
        'type' => 'powershell',
        'scripts' => ['../scripts/compact.ps1']
      }.freeze

      COMMON_POWERSHELL = {
        'type' => 'powershell',
        'scripts' => [
          '../scripts/setup_agent.ps1',
          'scripts/agent_config.ps1',
          '../scripts/cleanup-windows-features.ps1',
          '../scripts/disable-services.ps1',
          '../scripts/set-firewall.ps1',
          '../scripts/cleanup-artifacts.ps1'
        ]
      }.freeze
    end
  end
end
