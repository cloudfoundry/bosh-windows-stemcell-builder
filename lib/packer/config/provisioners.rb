require 'securerandom'

module Packer
  module Config
    class Provisioners
      CREATE_PROVISION_DIR = {
        'type' => 'powershell',
        'inline' => [
          'if (Test-Path C:\\provision) { Remove-Item -Path C:\\provision -Recurse -Force }',
          'New-Item -ItemType Directory -Path C:\\provision'
        ]
      }.freeze

      VMX_UPDATE_PROVISIONER = {
        'type' => 'file',
        'source' => 'scripts/vsphere/update-provisioner.ps1',
        'destination' => 'C:\\provision\\update-provisioner.ps1'
      }.freeze

      VMX_AUTORUN_UPDATES = {
        'type' => 'file',
        'source' => 'scripts/vsphere/autorun-updates.ps1',
        'destination' => 'C:\\provision\\autorun-updates.ps1'
      }.freeze

      VMX_POWERSHELLUTILS = {
        'type' => 'file',
        'source' => 'scripts/PowershellUtils.psm1',
        'destination' => 'C:\\provision\\PowershellUtils.psm1'
      }.freeze

      VMX_PSWINDOWSUPDATE = {
        'type' => 'file',
        'source' => 'build/windows-stemcell-dependencies/ps-windowsupdate/PSWindowsUpdate.zip',
        'destination' => 'C:\\provision\\PSWindowsUpdate.zip'
      }.freeze

      VMX_WINDOWS_RESTART = {
        'type' => 'windows-restart',
        'restart_command' => "powershell.exe C:\\provision\\autorun-updates.ps1 -AdminPassword ADMINISTRATOR_PASSWORD",
        'restart_timeout' => '12h'
      }

      VMX_READ_UPDATE_LOG = {
        'type' => 'powershell',
        'inline' => ['if (Test-Path C:\\update-logs.txt) { Get-Content -Path C:\\update-logs.txt } else { Write-Host "Missing log file" }']
      }.freeze

      VMX_STEMCELL_SYSPREP = {
        'type' => 'file',
        'source' => 'scripts/vsphere/sysprep.ps1',
        'destination' => 'C:\\sysprep.ps1'
      }.freeze

      ADD_VCAP_GROUP = {
        'type' => 'powershell',
        'scripts' => ['scripts/vsphere/add-vcap-group.ps1']
      }.freeze

      AGENT_DEPS_ZIP = {
        'type' => 'file',
        'source' => 'build/compiled-agent/agent-dependencies.zip',
        'destination' => 'C:\\bosh\\agent-dependencies.zip'
      }.freeze

      AGENT_ZIP = {
        'type' => 'file',
        'source' => 'build/compiled-agent/agent.zip',
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

      RUN_POLICIES = {
        'type' => 'powershell',
        'scripts' => ['scripts/vsphere/run-policies.ps1']
      }.freeze

      COMPACT_DISK = {
        'type' => 'powershell',
        'scripts' => ['scripts/compact.ps1']
      }.freeze

      DISABLE_AUTO_LOGON = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/vsphere/disable-auto-logon.bat']
      }.freeze

      DISABLE_SERVICES = {
        'type' => 'powershell',
        'scripts' => ['scripts/disable-services.ps1']
      }.freeze

      ENABLE_RDP = {
        'type' => 'windows-shell',
        'scripts' => ['scripts/vsphere/enable-rdp.bat']
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
        'source' => 'build/windows-stemcell-dependencies/lgpo/LGPO.exe',
        'destination' => 'C:\\LGPO.exe'
      }.freeze

      POLICY_BASELINE_ZIP = {
        'type' => 'file',
        'source' => 'build/windows-stemcell-dependencies/policy-baseline/policy-baseline.zip',
        'destination' => 'C:\\policy-baseline.zip'
      }.freeze

      RUN_LGPO = {
        'type' => 'powershell',
        'scripts' => ['scripts/run-lgpo.ps1']
      }.freeze

      CHECK_UPDATES = {
        'type' => 'powershell',
        'scripts' => ['scripts/check-updates.ps1']
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
        'source' => 'build/windows-stemcell-dependencies/VMware-tools/VMware-tools.exe',
        'destination' => 'C:\\VMWare-tools.exe'
      }.freeze

      VSPHERE_AGENT_CONFIG = {
        'type' => 'powershell',
        'scripts' => ['scripts/vsphere/agent_config.ps1']
      }.freeze

      INCREASE_WINRM_LIMITS = {
        'type' => 'powershell',
        'scripts' => ['scripts/increase-winrm-limits.ps1']
      }.freeze

      WINDOWS_RESTART = {
        'type' => 'windows-restart',
        'restart_timeout' => '1h'
      }.freeze
    end
  end
end
