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

      LGPO_EXE = {
        'type' => 'file',
        'source' => 'build/windows-stemcell-dependencies/lgpo/LGPO.exe',
        'destination' => 'C:\\windows\\LGPO.exe'
      }.freeze

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
