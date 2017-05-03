require 'securerandom'

module Packer
  module Config
    class Provisioners
      def self.install_windows_updates
        password = SecureRandom.hex(10)+"!"
        return [
          {
            'type' => 'powershell',
            'inline' => ["Add-Account -User Provisioner -Password #{password}"]
          },
          {
            'type' => 'powershell',
            'inline' => ["Register-WindowsUpdatesTask"]
          },
          {
            'type' => 'windows-restart',
            'restart_command' => "powershell.exe -Command Wait-WindowsUpdates -Password #{password} -User Provisioner",
            'restart_timeout' => '12h'
          },
          {
            'type' => 'powershell',
            'inline' => ["Unregister-WindowsUpdatesTask"]
          },
          {
            'type' => 'powershell',
            'inline' => ["Remove-Account -User Provisioner"]
          }, {
            'type' => 'powershell',
            'inline' => ['Test-InstalledUpdates']
          }
        ]
      end

      def self.download_windows_updates(dest)
        return [
          {
            'type' => 'powershell',
            'inline' => 'List-InstalledUpdates | Out-File -FilePath "C:\\updates.txt" -Encoding ASCII'
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

      INSTALL_CONTAINERS_FEATURE = [
        {
          'type' => 'powershell',
          'inline' => ['Install-ContainersFeature']
        }, {
          'type' => 'windows-restart',
          'restart_timeout' => '10m'
        }
      ].freeze

      PROTECT_CF_CELL = {
        'type' => 'powershell',
        'inline' => ['Protect-CFCell']
      }.freeze

      OPTIMIZE_DISK = {
        'type' => 'powershell',
        'inline' => ['Optimize-Disk']
      }.freeze

      COMPRESS_DISK = {
        'type' => 'powershell',
        'inline' => ['Compress-Disk']
      }.freeze

      CLEAR_PROVISIONER = {
        'type' => 'powershell',
        'inline' => ['Clear-Provisioner']
      }.freeze

      GET_LOG = {
        'type' => 'powershell',
        'inline' => ['Get-Log']
      }.freeze

      def self.lgpo_exe
        {
          'type' => 'file',
          'source' => File.join(Stemcell::Builder::validate_env_dir('STEMCELL_DEPS_DIR'), 'lgpo', 'LGPO.exe'),
          'destination' => 'C:\\windows\\LGPO.exe'
        }.freeze
      end

      def self.sysprep_shutdown(iaas)
        return [
          {
            'type' => 'powershell',
            'inline' => ["Invoke-Sysprep -IaaS #{iaas}"]
          }
        ]
      end
    end
  end
end
