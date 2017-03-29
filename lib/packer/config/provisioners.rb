require 'securerandom'

module Packer
  module Config
    class Provisioners
      def self.wait_windowsupdatestask(administrator_password)
        return {
          'type' => 'windows-restart',
          'restart_command' => "powershell.exe -Command Wait-WindowsUpdates -AdministratorPassword #{administrator_password}",
          'restart_timeout' => '12h'
        }
      end

      def self.install_agent(iaas)
        return {
          'type' => 'powershell',
          'inline' => ["Install-Agent -IaaS #{iaas} -agentZipPath 'C:\\provision\\agent.zip'"]
        }
      end

      REGISTER_WINDOWSUPDATESTASK= {
        'type' => 'powershell',
        'inline' => ["Register-WindowsUpdatesTask"]
      }.freeze

      CREATE_PROVISION_DIR = {
        'type' => 'powershell',
        'inline' => [
          'if (Test-Path C:\\provision) { Remove-Item -Path C:\\provision -Recurse -Force }',
          'New-Item -ItemType Directory -Path C:\\provision'
        ]
      }.freeze

      WAIT_WINDOWSUPDATESTASK = {
        'type' => 'windows-restart',
        'restart_command' => 'powershell.exe -Command Wait-WindowsUpdates',
        'restart_timeout' => '12h'
      }.freeze

      def self.download_windows_updates(dest)
        return [
          {
            'type' => 'powershell',
            'inline' => 'List-Updates | Out-File -FilePath "C:\\updates.txt" -Encoding ASCII'
          },
          {
            'type' => 'file',
            'source' => 'C:\\updates.txt',
            'destination' => File.join(dest, 'updates.txt'),
            'direction' => 'download'
          }
        ]
      end

      UNREGISTER_WINDOWSUPDATESTASK= {
        'type' => 'powershell',
        'inline' => ["Unregister-WindowsUpdatesTask"]
      }.freeze

      UPLOAD_BOSH_PSMODULES = {
        'type' => 'file',
        'source' => 'build/bosh-psmodules.zip',
        'destination' => 'C:\\provision\\bosh-psmodules.zip'
      }.freeze

      UPLOAD_AGENT = {
        'type' => 'file',
        'source' => 'build/agent.zip',
        'destination' => 'C:\\provision\\agent.zip'
      }.freeze

      INSTALL_BOSH_PSMODULES = {
        'type' => 'powershell',
        'scripts' => ['scripts/install-bosh-psmodules.ps1']
      }.freeze

      INSTALL_CF_FEATURES = {
        'type' => 'powershell',
        'inline' => ['Install-CFFeatures']
      }.freeze

      COMPRESS_DISK = {
        'type' => 'powershell',
        'inline' => ['Compress-Disk']
      }.freeze

      OUTPUT_LOG= {
        'type' => 'powershell',
        'inline' => ['if (Test-Path C:\\provision\\log.log) { Get-Content -Path C:\\provision\\log.log } else { Write-Host "Missing log file" }']
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

      INSTALL_VMWARE_TOOLS = {
        'type' => 'powershell',
        'scripts' => ['scripts/vm-guest-tools.ps1']
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

      SET_EC2_PASSWORD = {
        'type' => 'powershell',
        'scripts' => ['scripts/aws/ec2-set-password.ps1']
      }.freeze

      SET_FIREWALL = {
        'type' => 'powershell',
        'scripts' => ['scripts/set-firewall.ps1']
      }.freeze

      VMWARE_TOOLS_EXE = {
        'type' => 'file',
        'source' => 'build/windows-stemcell-dependencies/VMware-tools/VMware-tools.exe',
        'destination' => 'C:\\VMWare-tools.exe'
      }.freeze

      INCREASE_WINRM_LIMITS = {
        'type' => 'powershell',
        'scripts' => ['scripts/increase-winrm-limits.ps1']
      }.freeze

      DISABLE_WINRM_STARTUP = {
        'type' => 'powershell',
        'inline' => ['Get-Service -Name "WinRM" | Set-Service -StartupType Disabled']
      }.freeze

      WINDOWS_RESTART = {
        'type' => 'windows-restart',
        'restart_timeout' => '1h'
      }.freeze

      class Azure
        def self.create_admin(admin_password)
          return {
            'type' => 'powershell',
            'inline' => [
              "NET USER Administrator #{admin_password} /add /y /expires:never",
              'NET LOCALGROUP Administrators Administrator /add'
            ]
          }
        end

        SYSPREP_SHUTDOWN = {
          'type' => 'windows-shell',
          'inline' => ['C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /quiet /oobe /quit']
        }.freeze

      end
    end
  end
end
