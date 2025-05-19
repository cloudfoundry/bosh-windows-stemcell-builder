package packager

import (
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"regexp"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/filesystem"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
)

//counterfeiter:generate . IaasClient
type IaasClient interface {
	ValidateUrl() error
	ValidateCredentials() error
	FindVM(vmInventoryPath string) error
	ExportVM(vmInventoryPath string, destination string) error
	ListDevices(vmInventoryPath string) ([]string, error)
	RemoveDevice(vmInventoryPath string, deviceName string) error
	EjectCDRom(vmInventoryPath string, deviceName string) error
}

type VCenterPackager struct {
	SourceConfig config.SourceConfig
	OutputConfig config.OutputConfig
	Client       IaasClient
	Logger       colorlogger.Logger
}

func (v VCenterPackager) Package() error {
	err := v.executeOnMatchingDevice(v.Client.RemoveDevice, "^(floppy-|ethernet-)")
	if err != nil {
		return err
	}
	err = v.executeOnMatchingDevice(v.Client.EjectCDRom, "^(cdrom-)")
	if err != nil {
		return err
	}

	workingDir, err := os.MkdirTemp(os.TempDir(), "vcenter-packager-working-directory")

	if err != nil {
		return errors.New("failed to create working directory")
	}

	stemcellDir, err := os.MkdirTemp(os.TempDir(), "vcenter-packager-stemcell-directory")
	if err != nil {
		return errors.New("failed to create stemcell directory")
	}
	err = v.Client.ExportVM(v.SourceConfig.VmInventoryPath, workingDir)

	if err != nil {
		return errors.New("failed to export the prepared VM")
	}

	fmt.Println("Converting VMDK into stemcell")
	vmName := path.Base(v.SourceConfig.VmInventoryPath)
	shaSum, err := TarGenerator(filepath.Join(stemcellDir, "image"), filepath.Join(workingDir, vmName)) //nolint:ineffassign,staticcheck
	manifestContents := CreateManifest(v.OutputConfig.Os, v.OutputConfig.StemcellVersion, shaSum)
	err = WriteManifest(manifestContents, stemcellDir)

	if err != nil {
		return errors.New("failed to create stemcell.MF file")
	}

	stemcellFilename := StemcellFilename(v.OutputConfig.StemcellVersion, v.OutputConfig.Os)
	_, err = TarGenerator(filepath.Join(v.OutputConfig.OutputDir, stemcellFilename), stemcellDir) //nolint:ineffassign,staticcheck

	fmt.Printf("Stemcell successfully created: %s\n", stemcellFilename)
	return nil
}

func (v VCenterPackager) executeOnMatchingDevice(action func(a, b string) error, devicePattern string) error {
	deviceList, err := v.Client.ListDevices(v.SourceConfig.VmInventoryPath)
	if err != nil {
		return err
	}

	for _, deviceName := range deviceList {
		matched, _ := regexp.MatchString(devicePattern, deviceName) //nolint:errcheck
		if matched {
			err = action(v.SourceConfig.VmInventoryPath, deviceName)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (v VCenterPackager) ValidateFreeSpaceForPackage(_fs filesystem.FileSystem) error {
	return nil
}

func (v VCenterPackager) ValidateSourceParameters() error {
	err := v.Client.ValidateUrl()
	if err != nil {
		return err
	}

	err = v.Client.ValidateCredentials()
	if err != nil {
		return err
	}
	err = v.Client.FindVM(v.SourceConfig.VmInventoryPath)
	if err != nil {
		return err
	}
	return nil
}
