require 'securerandom'

module Packer
  module Config
    class Provisioners
      def self.install_windows_updates(administrator_password)
        return [
          {
            'type' => 'powershell',
            'inline' => ["Register-WindowsUpdatesTask"]
          },
          {
            'type' => 'windows-restart',
            'restart_command' => "powershell.exe -Command Wait-WindowsUpdates -AdministratorPassword #{administrator_password}",
            'restart_timeout' => '12h'
          },
          {
            'type' => 'powershell',
            'inline' => ["Unregister-WindowsUpdatesTask"]
          }
        ]
      end

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

      def self.install_agent(iaas)
        return [
          {
            'type' => 'file',
            'source' => 'build/agent.zip',
            'destination' => 'C:\\provision\\agent.zip'
          },
          {
            'type' => 'powershell',
            'inline' => ["Install-Agent -IaaS #{iaas} -agentZipPath 'C:\\provision\\agent.zip'"]
          }
        ]
      end

      BOSH_PSMODULES = [
        {
          'type' => 'file',
          'source' => 'build/bosh-psmodules.zip',
          'destination' => 'C:\\provision\\bosh-psmodules.zip'
        }, {
          'type' => 'powershell',
          'scripts' => ['scripts/install-bosh-psmodules.ps1']
        }
      ].freeze

      NEW_PROVISIONER = {
        'type' => 'powershell',
        'inline' => ['New-Provisioner']
      }.freeze

      INSTALL_CF_FEATURES = {
        'type' => 'powershell',
        'inline' => ['Install-CFFeatures']
      }.freeze

      PROTECT_CF_CELL = {
        'type' => 'powershell',
        'inline' => ['Protect-CFCell']
      }.freeze

      CLEAR_DISK = {
        'type' => 'powershell',
        'inline' => ['Clear-Disk']
      }.freeze

      COMPRESS_DISK = {
        'type' => 'powershell',
        'inline' => ['Compress-Disk']
      }.freeze

      CLEAR_PROVISIONER = [
        {
          'type' => 'powershell',
          'inline' => ['Get-Log']
        },
        {
          'type' => 'powershell',
          'inline' => ['Clear-Provisioner']
        }
      ].freeze

      ##TO BE KEPT ^^^^

      VMX_STEMCELL_SYSPREP = {
        'type' => 'file',
        'source' => 'scripts/vsphere/sysprep.ps1',
        'destination' => 'C:\\sysprep.ps1'
      }.freeze

      RUN_POLICIES = {
        'type' => 'powershell',
        'scripts' => ['scripts/vsphere/run-policies.ps1']
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

      VMWARE_TOOLS_EXE = {
        'type' => 'file',
        'source' => 'build/windows-stemcell-dependencies/VMware-tools/VMware-tools.exe',
        'destination' => 'C:\\VMWare-tools.exe'
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
