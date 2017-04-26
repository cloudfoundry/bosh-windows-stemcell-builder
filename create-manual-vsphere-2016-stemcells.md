# Creating a Windows 2016 vSphere Stemcell by Hand

## Create base VM for stemcell

Follow step #1 from [Windows 2012 vSphere stemcell](create-manual-vsphere-stemcells.md) docs to create a VM and install from a Windows 2016 ISO.

NOTE: Select "Windows 2012" as your OS so that you can use hardware version 9.

## Package BOSH PSModules, Install BOSH PSModules, Build & Install Agent

First load powershell, then define the unzip function:

```
function Unzip {
    param([string]$ZipFile, [string]$OutPath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)

    Remove-Item -Path $ZipFile -Force
}
Unzip -ZipFile {{PATH_TO_ZIP}} -OutPath {{OUTPUT_PATH}}
```

Follow steps #2, #3, and #5 from [Windows 2012 vSphere stemcell](create-manual-vsphere-stemcells.md), then shut down the VM.
You can use the above unzip function to unzip the BOSH PS modules.

(note: skip #4)

## Export image to OVA format

If you are using VMware Fusion or Workstation, after powering off the VM locate the directory that has your VM's `.vmx` file. This defaults to
the `Documents\\Virtual Machines\\VM-name\\VM-name.vmx` path in your user's home directory.
Otherwise simply right click on the VM to find its location.

Convert the vmx file into an OVA archive using `ovftool`:

```
ovftool <PATH_TO_VMX_FILE> image.ova
```

## Convert OVA file to a BOSH Stemcell

The format of the rake task is `rake package:vsphere_ova[<path_to_ova>,<path_to_stemcell_destination_directory>,stemcell_version]`

For example:
```
rake package:vsphere_ova[./build/image.ova,./build/stemcell,1035.0]
```

NOTE: The OVA filename and destination path cannot currently have spaces in them (this will be fixed).

## Flip out .ovf for old OVF

**NOTE**: Because the Hardware version 12 is incompatible with the vSphere BOSH CPI, you must replace the `.ovf` file inside
the stemcell's image with an `.ovf` file from a 2012 stemcell to ensure ESXI compatibility.
