require 'securerandom'

module Packer
  module Config
    class Provisioners
      ADD_VCAP_GROUP = {
        'type' => 'powershell',
        'scripts' => ['scripts/add-vcap-group.ps1']
      }.freeze

      AGENT_DEPS_ZIP = {
        'type' => 'file',
        'source' => 'compiled-agent/agent-dependencies.zip',
        'destination' => 'C:\\bosh\\agent-dependencies.zip'
      }.freeze

      AGENT_ZIP = {
        'type' => 'file',
        'source' => 'compiled-agent/agent.zip',
        'destination' => 'C:\\bosh\\agent.zip'
      }.freeze

      AWS_AGENT_CONFIG = {
        'type' => 'powershell',
        'scripts' => ['scripts/aws/agent_config.ps1']
      }.freeze

      CLEANUP_ARTIFACTS = {
        'type' => 'powershell',
        'scripts' => ['scripts/cleanup-artifacts.ps1']
      }.freeze

      CLEANUP_TEMP_DIRS = {
        'type' => 'powershell',
        'scripts' => ['scripts/cleanup-temp-directories.ps1']
      }.freeze

      CLEANUP_WINDOWS_FEATURES = {
        'type' => 'powershell',
        'scripts' => ['scripts/cleanup-windows-features.ps1']
      }.freeze

      COMPACT_DISK = {
        'type' => 'powershell',
        'scripts' => ['scripts/compact.ps1']
      }.freeze

      DISABLE_AUTO_LOGON = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/disable-auto-logon.bat']
      }.freeze

      DISABLE_SERVICES = {
        'type' => 'powershell',
        'scripts' => ['scripts/disable-services.ps1']
      }.freeze

      ENABLE_RDP = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/enable-rdp.bat']
      }.freeze

      GCP_AGENT_CONFIG = {
        'type' => 'powershell',
        'scripts' => ['scripts/gcp/agent_config.ps1']
      }.freeze

      INSTALL_VMWARE_TOOLS = {
        'type' => 'powershell',
        'scripts' => ['scripts/vm-guest-tools.ps1']
      }.freeze

      INSTALL_WINDOWS_FEATURES = {
        'type' => 'powershell',
        'scripts' => ['scripts/add-windows-features.ps1']
      }.freeze

      LGPO_EXE = {
        'type' => 'file',
        'source' => '../../windows-stemcell-dependencies/lgpo/LGPO.exe',
        'destination' => 'C:\\LGPO.exe'
      }.freeze

      RUN_LGPO = {
        'type' => 'powershell',
        'scripts' => ['scripts/run-lgpo.ps1']
      }.freeze

      SET_EC2_PASSWORD = {
        'type' => 'powershell',
        'scripts' => ['scripts/aws/ec2-set-password.ps1']
      }.freeze

      SET_FIREWALL = {
        'type' => 'powershell',
        'scripts' => ['scripts/set-firewall.ps1']
      }.freeze

      SETUP_AGENT = {
        'type' => 'powershell',
        'scripts' => ['scripts/setup_agent.ps1']
      }.freeze

      VMWARE_TOOLS_EXE = {
        'type' => 'file',
        'source' => '../../windows-stemcell-dependencies/VMware-tools/VMware-tools.exe',
        'destination' => 'C:\\VMWare-tools.exe'
      }.freeze

      VSPHERE_AGENT_CONFIG = {
        'type' => 'powershell',
        'scripts' => ['scripts/vsphere/agent_config.ps1']
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
    end
  end
end
