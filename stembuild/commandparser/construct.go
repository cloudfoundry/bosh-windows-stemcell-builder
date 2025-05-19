package commandparser

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/subcommands"
	"github.com/vmware/govmomi/guest"
	"github.com/vmware/govmomi/object"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/guest_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . VmConstruct
type VmConstruct interface {
	PrepareVM() error
}

//counterfeiter:generate . VCenterManager
type VCenterManager interface {
	OperationsManager(ctx context.Context, vm *object.VirtualMachine) *guest.OperationsManager
	GuestManager(ctx context.Context, opsManager vcenter_manager.OpsManager, username, password string) (*guest_manager.GuestManager, error)
	FindVM(ctx context.Context, inventoryPath string) (*object.VirtualMachine, error)
	Login(ctx context.Context) error
}

//counterfeiter:generate . VMPreparerFactory
type VMPreparerFactory interface {
	New(config config.SourceConfig, vCenterManager VCenterManager) (VmConstruct, error)
}

//counterfeiter:generate . ManagerFactory
type ManagerFactory interface {
	VCenterManager(ctx context.Context) (*vcenter_manager.VCenterManager, error)
	SetConfig(config vcenter_manager.FactoryConfig)
}

//counterfeiter:generate . ConstructCmdValidator
type ConstructCmdValidator interface {
	PopulatedArgs(...string) bool
	LGPOInDirectory() bool
}

//counterfeiter:generate . ConstructMessenger
type ConstructMessenger interface {
	ArgumentsNotProvided()
	LGPONotFound()
	CannotConnectToVM(err error)
	CannotPrepareVM(err error)
}

type ConstructCmd struct {
	ctx            context.Context
	sourceConfig   config.SourceConfig
	prepFactory    VMPreparerFactory
	managerFactory ManagerFactory
	validator      ConstructCmdValidator
	messenger      ConstructMessenger
	GlobalFlags    *GlobalFlags
}

type setupFlagsValue struct {
	sourceConfig *config.SourceConfig
}

func newSetupFlagsValue(sourceConfig *config.SourceConfig) setupFlagsValue {
	return setupFlagsValue{sourceConfig: sourceConfig}
}

func (v setupFlagsValue) String() string {
	return strings.Join(v.sourceConfig.SetupFlags, "; ")
}

func (v setupFlagsValue) Set(s string) error {
	v.sourceConfig.SetupFlags = append(v.sourceConfig.SetupFlags, s)
	return nil
}

func NewConstructCmd(ctx context.Context, prepFactory VMPreparerFactory, managerFactory ManagerFactory, validator ConstructCmdValidator, messenger ConstructMessenger) *ConstructCmd {
	return &ConstructCmd{ctx: ctx, prepFactory: prepFactory, managerFactory: managerFactory, validator: validator, messenger: messenger}
}

func (*ConstructCmd) Name() string { return "construct" }
func (*ConstructCmd) Synopsis() string {
	return "Provisions and syspreps an existing VM on vCenter, ready to be packaged into a stemcell"
}

func (*ConstructCmd) Usage() string {
	return fmt.Sprintf(`%[1]s construct -vm-ip <IP of VM> -vm-username <vm username> -vm-password <vm password>  -vcenter-url <vCenter URL> -vcenter-username <vCenter username> -vcenter-password <vCenter password> -vm-inventory-path <vCenter VM inventory path>

Prepares a VM to be used by stembuild package. It leverages stemcell automation scripts to provision a VM to be used as a stemcell.

Requirements:
	LGPO.zip in current working directory
	Running Windows VM with:
		- Up to date Operating System
		- Reachable by IP
		- Username and password with Administrator privileges
		- vCenter URL, username and password
		- vCenter Inventory Path
	The [vm-ip], [vm-username], [vm-password], [vcenter-url], [vcenter-username], [vcenter-password], [vm-inventory-path] must be specified

Example:
	%[1]s construct -vm-ip '10.0.0.5' -vm-username Admin -vm-password 'password' -vcenter-url vcenter.example.com -vcenter-username root -vcenter-password 'password' -vm-inventory-path '/datacenter/vm/folder/vm-name'

Flags:
`, filepath.Base(os.Args[0]))
}

func (p *ConstructCmd) SetFlags(f *flag.FlagSet) {
	f.StringVar(&p.sourceConfig.GuestVmIp, "vm-ip", "", "IP of target machine")
	f.StringVar(&p.sourceConfig.GuestVMUsername, "vm-username", "", "Username of target machine")
	f.StringVar(&p.sourceConfig.GuestVMPassword, "vm-password", "", "Password of target machine. Needs to be wrapped in single quotations.")
	f.StringVar(&p.sourceConfig.VCenterUrl, "vcenter-url", "", "vCenter url")
	f.StringVar(&p.sourceConfig.VCenterUsername, "vcenter-username", "", "vCenter username")
	f.StringVar(&p.sourceConfig.VCenterPassword, "vcenter-password", "", "vCenter password")
	f.StringVar(&p.sourceConfig.VmInventoryPath, "vm-inventory-path", "", "vCenter VM inventory path. (e.g: <datacenter>/vm/<vm-folder>/<vm-name>)")
	f.StringVar(&p.sourceConfig.CaCertFile, "vcenter-ca-certs", "", "filepath for custom ca certs")
	f.Var(newSetupFlagsValue(&p.sourceConfig), "setup-arg", "a 'flag value' combination to be passed to Setup.ps1 - can be set multiple times")
}

func (p *ConstructCmd) Execute(_ context.Context, f *flag.FlagSet, _ ...interface{}) subcommands.ExitStatus {
	c := p.sourceConfig
	if !p.validator.PopulatedArgs(c.GuestVmIp, c.GuestVMUsername, c.GuestVMPassword, c.VCenterUrl, c.VCenterUsername, c.VCenterPassword, c.VmInventoryPath) {
		p.messenger.ArgumentsNotProvided()
		return subcommands.ExitFailure
	}
	if !p.validator.LGPOInDirectory() {
		p.messenger.LGPONotFound()
		return subcommands.ExitFailure
	}

	p.managerFactory.SetConfig(vcenter_manager.FactoryConfig{
		VCenterServer:  p.sourceConfig.VCenterUrl,
		Username:       p.sourceConfig.VCenterUsername,
		Password:       p.sourceConfig.VCenterPassword,
		ClientCreator:  &vcenter_manager.ClientCreator{},
		FinderCreator:  &vcenter_manager.GovmomiFinderCreator{},
		RootCACertPath: p.sourceConfig.CaCertFile,
	})

	vCenterManager, err := p.managerFactory.VCenterManager(p.ctx)
	if err != nil {
		p.messenger.CannotPrepareVM(err)
		return subcommands.ExitFailure
	}

	vmConstruct, err := p.prepFactory.New(p.sourceConfig, vCenterManager)
	if err != nil {
		p.messenger.CannotPrepareVM(err)
		return subcommands.ExitFailure
	}

	err = vmConstruct.PrepareVM()
	if err != nil {
		p.messenger.CannotPrepareVM(err)
		return subcommands.ExitFailure
	}

	return subcommands.ExitSuccess
}
