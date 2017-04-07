# Creating a vSphere Stemcell by Hand

## Introduction

In order to create a vSphere stemcell by hand, you must first begin with an ISO or other VM image.
This document describes using VMware Workstation, VMware Fusion, and vCenter to install the BOSH
dependencies and then create a `.tgz` file that can be uploaded to your BOSH director and used
with Cloud Foundry.

**NOTE** This process is based on the fact that the operator is maintaining an updated template with all Windows recommended
security updates. You can determine if your image needs updates by creating a VM with the image and going to control panel.
If any critical or important updates are available we recommend installing updates first, then rebuilding the stemcell.
Every release of this repo includes a file `updates.txt` that lists the currently recommended `KB` Microsoft hotfixes to have installed.

### Dependencies

You will need:

* [ovftool](https://www.vmware.com/support/developer/ovf/) (only required for Workstation and Fusion). Please make sure `ovftool` command is available from your command line.
  It is installed by default in `C:\Program Files\VMware\VMware OVF Tool`.
* [Windows ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2012-r2) (evaluation. you can also use a custom base image)
* [Golang](https://golang.org/dl/) Latest 1.8.x compiler
* [Ruby](https://www.ruby-lang.org/en/downloads/) Latest 2.3.x version
* VMware Workstation, or VMware Fusion, or access to a vSphere account
* [git](https://git-scm.com/downloads)
* [tar.exe](https://greenhouse.ci.cf-app.com/teams/main/pipelines/tar/resources/s3-bucket) If on Windows
* [VMware Tools](https://packages.vmware.com/tools/esx/6.0latest/windows/x64/VMware-tools-10.0.9-3917699-x86_64.exe)

## Step 1: Create base VM for stemcell

NOTE: These are instructions for installing windows from a Windows installation disk ISO.
You may adapt the instructions if you are starting from some different Windows image. Make sure
that your image **has `Hardware Compatibility` set to version 9**, and that it has VMware tools
installed.

### For VMware Fusion:

1. File => New
1. Select Installation Method: Create a custom virtual machine
1. Choose Operating System: Microsoft Windows => Windows Server 2012
1. Choose a Virtual Disk: Create a new virtual disk (default settings are fine)
1. Select `Customize Settings`. Save the VM before continuing (any name will do)
1. A "Settings" window will pop up for your new VM. In the settings window, do the following:
  - Removable Devices =>
    - Camera =>
      - Remove device (incompatible with Hardware Version 9)
    - CD/DVD =>
      - Check the box 'Connect CD/DVD Drive'
      - From "This drive is configured to use the following:", select "Choose a disc or disc image" and select your base iso
      - Advanced Options => Bus type => SCSI (required for HW version 9)
  - Other => Compatibility => Advanced Options: Select "Use Hardware Version" number 9 and click apply
  - System Settings => Processor & Memory => Increase if desired (the defaults are fine, but a little slow).
1. Start VM - Go through Windows installation process if you need to with your ISO (recommend select "Windows Server 2012 Standard with a GUI" if going through installation)
1. Install VMware Tools (in Fusion, you can do this easily from the menu bar with "Virtual Machine" => "Install VMWare Tools", then following install instructions. Restart the VM as required to finish the install.
1. Shutdown the VM
1. Removable Devices => CD/DVD =>
  - Select 'Autodetect' (i.e. remove install ISO)
  - Unselect 'Connect CD/DVD Drive'
  - Click 'Advanced Options', and switch 'Bus type' to 'IDE'
1. Turn on and turn off the VM (required to apply changes to CD/DVD)
1. Ensure Hardware Compatibility is version 9

### For VMware Workstation:

- Install VMWare workstation (> version 12 Pro)
- Create a new Virtual Machine 
  - Custom Advanced
  - Select Worksation 9.x Compatibility
  - Select "I will install operating system later"
  - Select the Windows 2012 version
  - Choose a name
  - BIOS
  - Adjust the appropriate Number of cores and processors
  - Adjust the appropriate memory
  - Select the correct Network Type (NAT)
  - LSI logic SAS Contoller Type
  - SCSI Disk Type 
  - Create a new virtual Disk
  - Adjust the size (Default 60GB) and Store virtual disk as a single file
  - Before finishing, select Customize Hardware:
    - Select New CD/DVD
    - Select "Use ISO Image file" and browse for the correct ISO
- Power on the new VM and install Windows
  - Select server with GUI
  - Select custom installation
  - Follow along the installation process, and add select a password for Administrator user
- After the VM has started successfully, right-click the machine name in Workstation and Install VMware Tools
- Shut down the VM
- Remove the ISO file from the CD/DVD drive
  - Select the settings for the VM
  - CD/DVD Remove
  - Add CD/DVD Drive
  - Select "Use Physical drive" and Auto Detect
  - Unselect "Connect at power on"
  - Click Ok
- Start the new VM

### For vCenter:

- If you are using an ISO, upload it to your datastore (you may need to install a web plugin to upload through your browser)
  - Click vCenter -> Datastores
  - Select desired datastore, and desired directory
  - Click "Upload a file to datastore" (harddisk icon with green plus), and upload ISO.

Create a new virtual machine (if you are using an existing template, select the creation type `Deploy from template` and select a template):

- In `Select compatibility` ensure that you choose `ESXi 5.5 and later` 
- Select Windows as `Guest OS Family` and Microsoft Windows Server 2012 as `Guest OS version`
- In `Customize hardware`
    - Select `Datastore ISO File` under `New CD\DVD Drive`
    - Expand the menu and select `Connect At Power On`
    - Click `Browse` and select the ISO you uploaded to your datastore
- After creating VM, click Power On in the `Actions` tab for your VM, then install Windows:
  - Select server with GUI
  - Select custom installation
  - Follow along the installation process, and add select a password for Administrator user
- In the vCenter web client, "Install VMware Tools" in the VM `Summary` tab.

## Step 2: Package BOSH PSModules

If you do not have Ruby to package the BOSH PSModules, skip this step and download the `bosh-psmodules.zip` attached in your desired release.

- Clone [this repo](https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder) on your host (NOT in the VM for your stemcell), and expand the bosh-agent submodule:

**NOTE**: Do not use the GitHub generated `Source Code.zip` and `Source Code.tar.gz` files from the releases page - they are not Git repositories and are missing submodules.

**NOTE**: On Windows you MUST clone straight into `C:\\`, or the git clone and submodule update will fail due to file path lengths.

```
git clone --recursive https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder
git checkout <DESIRED_STEMCELL_VERSION_TAG>
cd bosh-windows-stemcell-builder
gem install bundler
bundle install
rake package:psmodules
```

## Step 3: Install BOSH PSModules

- Transfer the `build/bosh-psmodules.zip` you built in Step 2, or the `bosh-psmodules.zip` downloaded from the releases page to your Windows VM (Note: you can just drag and drop files if you have installed VMware tools in your VM and are running Workstation or Fusion)
- Unzip the zip file and copy the `BOSH.*` folders to `C:\Program Files\WindowsPowerShell\Modules`

## Step 4: Install CloudFoundry Cell requirements

- On your windows VM, start `powershell` and run `Install-CFFeatures`
- **Optional** If you would like to apply the recommended ingress and service configuration:
    - Run the following powershell command `Protect-CFCell`

## Step 5: Build & Install BOSH Agent

If you do not have Ruby and Golang to package the BOSH Agent, skip the first step below and download the `agent.zip` attached in your desired release.

- On your host (NOT in the VM for your stemcell), run `rake package:agent`
- Transfer `build/agent.zip` you built in the previous step, or the `agent.zip` downloaded from the releases page to your Windows VM.
- On your Windows VM, start `powershell` and run `Install-Agent -IaaS vsphere -agentZipPath <PATH_TO_agent.zip>`

## (Optional) Apply security policies and sysprep

This step is recommended, but not necessary. Power off the VM if none of the options below is applicable.

**1)** If you would like to enable the recommended local security policy without running sysprep:

  - Download [lgpo.exe](https://msdnshared.blob.core.windows.net/media/2016/09/LGPOv2-PRE-RELEASE.zip) to the Windows VM you are provisioning
  - Run the following powershell command `Enable-LocalSecurityPolicy -LgpoExe <PATH-TO-LGPO-EXE> -PolicyDestination "C:\bosh\lgpo"`
  - Power off your VM

Or:

**2)** If you would like to run the recommended sysprep:

  - Download [lgpo.exe](https://msdnshared.blob.core.windows.net/media/2016/09/LGPOv2-PRE-RELEASE.zip) to the Windows VM you are provisioning and save `lgpo.exe` to `C:\Windows\lgpo.exe`
  - Run the following powershell command `Invoke-Sysprep -IaaS vsphere -NewPassword <NEW_PASSWORD> -ProductKey <PRODUCT_KEY> -Owner <OWNER> -Organization <ORGANIZATION>`
  - This will power off the VM
  - Do not turn the VM back on before exporting

## Step 6: Export image to OVA format

If you are using VMware Fusion or Workstation, after powering off the VM locate the directory that has your VM's `.vmx` file. This defaults to
the `Documents\\Virtual Machines\\VM-name\\VM-name.vmx` path in your user's home directory.
Otherwise simply right click on the VM to find its location.

Convert the vmx file into an OVA archive using `ovftool`:

```
ovftool <PATH_TO_VMX_FILE> image.ova
```

## Step 7: Convert OVA file to a BOSH Stemcell

The format of the rake task is `rake package:vsphere_ova[<path_to_ova>,<path_to_stemcell_destination_directory>,stemcell_version]`

For example:
```
rake package:vsphere_ova[./build/image.ova,./build/stemcell,1035.0.0]
```

NOTE: The OVA filename and destination path cannot currently have spaces in them (this will be fixed).

