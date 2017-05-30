require 'securerandom'

module Packer
  module Config
    class Provisioners

      def self.powershell_provisioner(command)
        {
          'type' => 'powershell',
          'inline' => [
            '$ErrorActionPreference = "Stop";',
            'trap { $host.SetShouldExit(1) }',
            command
          ]
        }
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
      NEW_PROVISIONER = powershell_provisioner('New-Provisioner')
      INSTALL_CONTAINERS = {
        'type' => 'windows-restart',
        'restart_command' => "powershell.exe -Command Install-ContainersFeature",
        'restart_timeout' => '1h'
      }
      INSTALL_CF_FEATURES = powershell_provisioner('Install-CFFeatures')
      PROTECT_CF_CELL = powershell_provisioner('Protect-CFCell')
      OPTIMIZE_DISK = powershell_provisioner('Optimize-Disk')
      COMPRESS_DISK = powershell_provisioner('Compress-Disk')
      CLEAR_PROVISIONER = powershell_provisioner('Clear-Provisioner')
      GET_LOG = powershell_provisioner('Get-Log')

      def self.install_windows_updates
        password = SecureRandom.hex(10)+"!"
        return [
          powershell_provisioner("Add-Account -User Provisioner -Password #{password}"),
          powershell_provisioner("Register-WindowsUpdatesTask"),
          {
            'type' => 'windows-restart',
            'restart_command' => "powershell.exe -Command Wait-WindowsUpdates -Password #{password} -User Provisioner",
            'restart_timeout' => '12h'
          },
          powershell_provisioner("Unregister-WindowsUpdatesTask"),
          powershell_provisioner("Remove-Account -User Provisioner"),
          powershell_provisioner("Test-InstalledUpdates")
        ]
      end

      def self.download_windows_updates(dest)
        return [
          powershell_provisioner('List-InstalledUpdates | Out-File -FilePath "C:\\updates.txt" -Encoding ASCII'),
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
          powershell_provisioner("Install-Agent -IaaS #{iaas} -agentZipPath 'C:\\provision\\agent.zip'")
        ]
      end

      def self.lgpo_exe
        {
          'type' => 'file',
          'source' => File.join(Stemcell::Builder::validate_env_dir('STEMCELL_DEPS_DIR'), 'lgpo', 'LGPO.exe'),
          'destination' => 'C:\\windows\\LGPO.exe'
        }.freeze
      end

      def self.sysprep_shutdown(iaas)
        return [powershell_provisioner("Invoke-Sysprep -IaaS #{iaas}")]
      end
    end
  end
end
