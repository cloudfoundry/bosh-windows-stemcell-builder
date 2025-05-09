package templates

import (
	"errors"
	"io"
	"os"
	"text/template"
)

const vmxTemplate = `.encoding = "UTF-8"
checkpoint.vmState = ""
cleanShutdown = "TRUE"
config.version = "8"
displayName = "BOSH-Windows-Stemcell"
ehci.pciSlotNumber = "34"
ehci.present = "TRUE"
ehci:0.deviceType = "video"
ehci:0.parent = "-1"
ehci:0.port = "0"
floppy0.present = "FALSE"
guestOS = "windows8srv-64"
hgfs.linkRootShare = "true"
hgfs.mapRootShare = "true"
hpet0.present = "TRUE"
ide0:0.autodetect = "TRUE"
ide0:0.deviceType = "cdrom-raw"
ide0:0.fileName = "auto detect"
ide0:0.present = "TRUE"
ide0:0.startConnected = "FALSE"
isolation.tools.hgfs.disable = "false"
mem.hotadd = "TRUE"
memsize = "2048"
mks.enable3d = "TRUE"
monitor.phys_bits_used = "40"
numvcpus = "2"
pciBridge0.pciSlotNumber = "17"
pciBridge0.present = "TRUE"
pciBridge4.functions = "8"
pciBridge4.pciSlotNumber = "21"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge5.pciSlotNumber = "22"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge6.pciSlotNumber = "23"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
pciBridge7.pciSlotNumber = "24"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
powerType.powerOff = "soft"
powerType.powerOn = "soft"
powerType.reset = "soft"
powerType.suspend = "soft"
sata0.present = "FALSE"
sata0:1.present = "FALSE"
scsi0.pciSlotNumber = "160"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsisas1068"
scsi0:0.fileName = "{{.VMDKFile}}"
scsi0:0.present = "TRUE"
scsi0:0.redo = ""
serial0.fileType = "thinprint"
serial0.present = "TRUE"
softPowerOff = "TRUE"
tools.remindInstall = "FALSE"
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"
toolsInstallManager.lastInstallError = "0"
toolsInstallManager.updateCounter = "1"
vcpu.hotadd = "TRUE"
virtualHW.productCompatibility = "hosted"
virtualHW.version = "{{.HWVersion}}"
vmci0.pciSlotNumber = "35"
vmci0.present = "TRUE"
`

func VMXTemplate(vmdkPath string, virtualHWVersion int, w io.Writer) error {
	if vmdkPath == "" {
		return errors.New("vmx template: empty vmdk filename")
	}
	type context struct {
		VMDKFile  string
		HWVersion int
	}
	ctxt := context{VMDKFile: vmdkPath, HWVersion: virtualHWVersion}
	t, err := template.New("vmx template").Parse(vmxTemplate)
	if err != nil {
		return err
	}
	return t.Execute(w, ctxt)
}

// WriteVMXTemplate writes the VMX template for VMDK vmdk to file filename.
func WriteVMXTemplate(vmdkPath string, virtualHWVersion int, vmxPath string) error {
	f, err := os.OpenFile(vmxPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	err = VMXTemplate(vmdkPath, virtualHWVersion, f)
	f.Close() //nolint:errcheck
	if err != nil {
		os.Remove(vmxPath) //nolint:errcheck
	}
	return err
}
