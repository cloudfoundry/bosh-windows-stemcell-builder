# Workstation setup

* Ubuntu 16.04
* `sudo apt install virtinst virt-manager qemu-kvm`
* `sudo usermod -a -G libvirtd <username>`

where `username` is the user you will run these steps as.

# Stemcell creation

1. Download a Windows 2012R2 iso (we will call it `windows2012-disk.iso` in these instructions)
1. Download the [Windows virtio drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)
1. Create a qcow2 disk image

   ```
   qemu-img create -f qcow2 ws2012.qcow2 30G
   ```

1. Start a windows VM with the qcow2 disk, windows installer, and virtio drivers attached:

   ```
   virt-install --connect qemu:///system \
     --name ws2012 --ram 4096 --vcpus 2 \
     --network network=default,model=virtio \
     --disk path=ws2012.qcow2,format=qcow2,device=disk,bus=virtio \
     --disk path=~/Downloads/windows2012-disk.iso,device=cdrom \
     --disk path=~/Downloads/virtio-win-0.1.126.iso,device=cdrom \
     --vnc --os-type windows --os-variant win2k12
   ```

1. Install windows on the qcow2 disk
  * Pick Windows Server 2012 R2 Standard (Server with a GUI)
  * Custom install
  * Click `Load driver` -> `Browse`, select `E:\viostor\2k12R2\amd64`, select the only driver, and click `Next`
  * Continue and finish install

1. Install required Openstack drivers and Cloudbase-init
  * Open a powershell terminal. Install the redhat ethernet driver:

  ```
  pnputil -i -a E:\NetKVM\2k12R2\amd64\netkvm.inf
  ```

  * Download and Install Cloudbase-init:

  ```
  C:\Invoke-WebRequest -UseBasicParsing https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi -OutFile cloudbaseinit.msi
  .\cloudbase-init.msi
  ```

  * For cloudbase-init installer, choose username `Administrator`, uncheck `Use metadata password`, select `COM1` for Serial port for logging
  * Do NOT check boxes to run sysprep or shutdown. Finish install.

  * **OPTIONAL** Set password for administrator: If you would like to log in as Administrator to the stemcell for debugging (or anything else),
  run the following modification to the default unattend.xml for cloudbase-init:

   ```
   New-Item -ItemType "file" -path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\setup-admin.ps1" -Value @'
   $NewPassword = "My-Admin-Password!"
   $AdminUser = [ADSI]"WinNT://${env:computername}/Administrator,User"
   $AdminUser.SetPassword($NewPassword)
   $AdminUser.passwordExpired = 0
   $AdminUser.setinfo()
   '@

   New-Item -ItemType "file" -path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml" -Force -Value @"
   <?xml version="1.0" encoding="utf-8"?>
   <unattend xmlns="urn:schemas-microsoft-com:unattend">
     <settings pass="generalize">
       <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	 <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
       </component>
     </settings>
     <settings pass="oobeSystem">
       <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
	 <OOBE>
	   <HideEULAPage>true</HideEULAPage>
	   <NetworkLocation>Work</NetworkLocation>
	   <ProtectYourPC>1</ProtectYourPC>
	   <SkipMachineOOBE>true</SkipMachineOOBE>
	   <SkipUserOOBE>true</SkipUserOOBE>
	 </OOBE>
       </component>
     </settings>
     <settings pass="specialize">
       <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	 <RunSynchronous>
	   <RunSynchronousCommand wcm:action="add">
	     <Order>1</Order>
	     <Path>"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\Python\Scripts\cloudbase-init.exe" --config-file "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf"</Path>
	     <Description>Run Cloudbase-Init to set the hostname</Description>
	     <WillReboot>Never</WillReboot>
	   </RunSynchronousCommand>
	   <RunSynchronousCommand wcm:action="add">
	     <Order>2</Order>
	     <Path>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\setup-admin.ps1"</Path>
	     <Description>password</Description>
	     <WillReboot>Always</WillReboot>
	   </RunSynchronousCommand>
	 </RunSynchronous>
       </component>
     </settings>
   </unattend>
   "@
   ```

1. Install Bosh Agent and CF dependencies

  * Download `agent.zip` and `bosh-psmodules.zip` from the latest bosh-windows-stemcell-builder release:

    ```
    Invoke-WebRequest -uri https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/releases/download/1056.0/bosh-psmodules.zip -outfile bosh-psmodules.zip
    Invoke-WebRequest -uri https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/releases/download/1056.0/agent.zip -outfile agent.zip
    ```

  Make sure to replace `1056` with the latest stemcell version.

  * Extract `bosh-psmodules.zip` and move all the `BOSH.*` directories into `C:\Program Files\WindowsPowerShell\Modules`

  * Install the Agent and CF dependencies:

     ```
     Install-CFFeatures
     Protect-CFCell
     Install-Agent -IaaS openstack -agentZipPath <path-to-agent.zip>
     ```

  * Optionally apply security policies as described in [create-manual-vsphere-stemcells.md]

1. Complete sysprep in the VM

   ```powershell
   C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /quiet /shutdown /unattend:'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
   ```

1. Package the qcow2 disk into a stemcell

   ```bash
   mv ws2012.qcow2 root.img
   tar czf image root.img
   image_sha=$(sha1sum image | awk '{ print $1 }')
   version='7777.7' # Use whatever version you'd like
   echo "---
name: bosh-openstack-kvm-windows-go_agent
version: '$version'
bosh_protocol: 1
sha1: $image_sha
operating_system: 'windows2012R2'
cloud_properties:
  name: bosh-openstack-kvm-windows-go_agent
  version: '$version'
  infrastructure: openstack
  disk: 30000
  disk_format: qcow2
  container_format: bare
  os_type: windows" > stemcell.MF
   tar czf openstack-stemcell.tgz stemcell.MF image
   ```
