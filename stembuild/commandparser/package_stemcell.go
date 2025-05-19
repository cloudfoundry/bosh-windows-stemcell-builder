package commandparser

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/google/subcommands"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/filesystem"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
)

//counterfeiter:generate . OSAndVersionGetter
type OSAndVersionGetter interface {
	GetVersion() string
	GetVersionWithPatchNumber(string) string
	GetOs() string
}

//counterfeiter:generate . PackagerFactory
type PackagerFactory interface {
	NewPackager(sourceConfig config.SourceConfig, outputConfig config.OutputConfig, logger colorlogger.Logger) (Packager, error)
}

//counterfeiter:generate . Packager
type Packager interface {
	Package() error
	ValidateFreeSpaceForPackage(fs filesystem.FileSystem) error
	ValidateSourceParameters() error
}

//counterfeiter:generate . PackagerMessenger
type PackagerMessenger interface {
	InvalidOutputConfig(error)
	CannotCreatePackager(error)
	DoesNotHaveEnoughSpace(error)
	SourceParametersAreInvalid(error)
	PackageFailed(error)
}

type PackageCmd struct {
	GlobalFlags        *GlobalFlags
	sourceConfig       config.SourceConfig
	outputConfig       config.OutputConfig
	osAndVersionGetter OSAndVersionGetter
	packagerFactory    PackagerFactory
	packagerMessenger  PackagerMessenger
}

func NewPackageCommand(o OSAndVersionGetter, p PackagerFactory, m PackagerMessenger) *PackageCmd {
	return &PackageCmd{
		osAndVersionGetter: o,
		packagerFactory:    p,
		packagerMessenger:  m,
	}
}

var patchVersion string

func (*PackageCmd) Name() string { return "package" }
func (*PackageCmd) Synopsis() string {
	return "Create a BOSH Stemcell from a VMDK file or a provisioned vCenter VM"
}
func (*PackageCmd) Usage() string {
	return fmt.Sprintf(`
Create a BOSH Stemcell from a VMDK file or a provisioned vCenter VM

VM on vCenter:

  %[1]s package -vcenter-url <vCenter URL> -vcenter-username <vCenter username> -vcenter-password <vCenter password> -vm-inventory-path <vCenter VM inventory path>

  Requirements:
    - VM provisioned using the stembuild construct command
    - Access to vCenter environment
    - The [vcenter-url], [vcenter-username], [vcenter-password], and [vm-inventory-path] flags must be specified.
    - NOTE: The 'vm' keyword must be included between the datacenter name and folder name for the vm-inventory-path (e.g: <datacenter>/vm/<vm-folder>/<vm-name>) 
  Example:
    %[1]s package -vcenter-url vcenter.example.com -vcenter-username root -vcenter-password 'password' -vm-inventory-path '/my-datacenter/vm/my-folder/my-vm' 

VMDK: 

  %[1]s package -vmdk <path-to-vmdk> 

  Requirements:
    - The VMware 'ovftool' binary must be on your path or Fusion/Workstation
    must be installed (both include the 'ovftool').
    - The [vmdk] flag must be specified.  If the [output] flag is
    not specified the stemcell will be created in the current working directory.

  Example:
    %[1]s package -vmdk my-1803-vmdk.vmdk 

    Will create an Windows 1803 stemcell using [vmdk] 'my-1803-vmdk.vmdk'
    The final stemcell will be found in the current working directory.

Flags:
`, filepath.Base(os.Args[0]))
}

func (p *PackageCmd) SetFlags(f *flag.FlagSet) {
	f.StringVar(&p.sourceConfig.Vmdk, "vmdk", "", "VMDK file to create stemcell from")
	f.StringVar(&p.sourceConfig.VmInventoryPath, "vm-inventory-path", "", "vCenter VM inventory path. (e.g: <datacenter>/vm/<vm-folder>/<vm-name>)")
	f.StringVar(&p.sourceConfig.Username, "vcenter-username", "", "vCenter username")
	f.StringVar(&p.sourceConfig.Password, "vcenter-password", "", "vCenter password")
	f.StringVar(&p.sourceConfig.URL, "vcenter-url", "", "vCenter url")
	f.StringVar(&p.sourceConfig.CaCertFile, "vcenter-ca-certs", "", "filepath for custom ca certs")

	f.StringVar(&p.outputConfig.OutputDir, "outputDir", "", "Output directory, default is the current working directory.")
	f.StringVar(&p.outputConfig.OutputDir, "o", "", "Output directory (shorthand)")
	f.StringVar(&patchVersion, "patch-version", "", "Number or name of the patch version for the stemcell being built (e.g: for 2019.12.3 the string would be \"3\")")
}

func (p *PackageCmd) Execute(_ context.Context, f *flag.FlagSet, _ ...interface{}) subcommands.ExitStatus {

	logLevel := colorlogger.NONE
	if p.GlobalFlags.Debug {
		logLevel = colorlogger.DEBUG
	}

	p.setOSandStemcellVersions()

	err := p.outputConfig.ValidateConfig()
	if err != nil {
		p.packagerMessenger.InvalidOutputConfig(err)
		return subcommands.ExitFailure
	}

	logger := colorlogger.New(logLevel, p.GlobalFlags.Color, os.Stderr)
	packager, err := p.packagerFactory.NewPackager(p.sourceConfig, p.outputConfig, logger)
	if err != nil {
		p.packagerMessenger.CannotCreatePackager(err)
		return subcommands.ExitFailure
	}

	err = packager.ValidateFreeSpaceForPackage(&filesystem.OSFileSystem{})
	if err != nil {
		p.packagerMessenger.DoesNotHaveEnoughSpace(err)
		return subcommands.ExitFailure
	}

	err = packager.ValidateSourceParameters()
	if err != nil {
		p.packagerMessenger.SourceParametersAreInvalid(err)
		return subcommands.ExitFailure
	}

	if err := packager.Package(); err != nil {
		p.packagerMessenger.PackageFailed(err)
		return subcommands.ExitFailure
	}

	return subcommands.ExitSuccess
}

func (p *PackageCmd) setOSandStemcellVersions() {
	p.outputConfig.Os = p.osAndVersionGetter.GetOs()

	if patchVersion == "" {
		p.outputConfig.StemcellVersion = p.osAndVersionGetter.GetVersion()
	} else {
		p.outputConfig.StemcellVersion = p.osAndVersionGetter.GetVersionWithPatchNumber(patchVersion)
	}
}
