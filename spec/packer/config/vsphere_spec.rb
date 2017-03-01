require 'packer/config'

describe Packer::Config::VSphere do
  describe 'builders' do
    it 'returns the expected builders' do
      pending('vSphere builder being transitioned to VMX')
      fail

      builders = Packer::Config::VSphere.new('isourl', 'isochecksum',
                                             'winrmhost', 'password', 1, 1).builders
      expect(builders[0]).to eq(
        'type' => 'vmware-iso',
        'iso_url' => 'isourl',
        'iso_checksum_type' => 'md5',
        'iso_checksum' => 'isochecksum',
        'headless' => false,
        'boot_wait' => '2m',
        'communicator' => 'winrm',
        'winrm_username' => 'Administrator',
        'winrm_password' => 'vagrant',
        'winrm_timeout' => '72h',
        'winrm_insecure' => true,
        'winrm_host' => 'winrmhost',
        'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -File a =>\\sysprep.ps1 -NewPassword password',
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
          'memsize' => '1',
          'numvcpus' => '1',
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
      )
    end
  end

  describe 'provisioners' do
    it 'returns the expected provisioners' do
      pending('vSphere builder being transitioned to VMX')
      fail

      provisioners = Packer::Config::VSphere.new('', '', '', '', 1, 1).provisioners
      expect(provisioners).to eq(
        [
        ]
      )
    end
  end
end
