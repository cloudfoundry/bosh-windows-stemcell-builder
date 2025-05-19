package vcenter_manager

import (
	"context"
	"net/url"
	"path"
	"strings"

	"github.com/vmware/govmomi/find"
	"github.com/vmware/govmomi/guest"
	"github.com/vmware/govmomi/object"
	"github.com/vmware/govmomi/vim25"
	"github.com/vmware/govmomi/vim25/types"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/guest_manager"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . GovmomiClient
type GovmomiClient interface {
	Login(ctx context.Context, u *url.Userinfo) error
}

//counterfeiter:generate . Finder
type Finder interface {
	VirtualMachine(ctx context.Context, path string) (*object.VirtualMachine, error)
	DatacenterOrDefault(ctx context.Context, path string) (*object.Datacenter, error)
	ResourcePoolOrDefault(ctx context.Context, path string) (*object.ResourcePool, error)
	SetDatacenter(dc *object.Datacenter) *find.Finder
	FolderOrDefault(ctx context.Context, path string) (*object.Folder, error)
}

//counterfeiter:generate . OpsManager
type OpsManager interface {
	ProcessManager(ctx context.Context) (*guest.ProcessManager, error)
	FileManager(ctx context.Context) (*guest.FileManager, error)
}

type VCenterManager struct {
	govmomiClient GovmomiClient
	vimClient     *vim25.Client
	finder        Finder
	username      string
	password      string
}

func NewVCenterManager(govmomiClient GovmomiClient, vimClient *vim25.Client, finder Finder, username, password string) (*VCenterManager, error) {
	return &VCenterManager{govmomiClient: govmomiClient, vimClient: vimClient, finder: finder, username: username, password: password}, nil
}

func (v *VCenterManager) Login(ctx context.Context) error {
	credentials := url.UserPassword(v.username, v.password)
	err := v.govmomiClient.Login(ctx, credentials)
	if err != nil {
		return err
	}
	return nil
}

func (v *VCenterManager) FindVM(ctx context.Context, inventoryPath string) (*object.VirtualMachine, error) {

	vm, err := v.finder.VirtualMachine(ctx, inventoryPath)
	if err != nil {
		return nil, err
	}

	return vm, nil
}

// CloneVM clones vm to clonePath. It currently does no network configuration (i.e. there is no IP assigned)
func (v *VCenterManager) CloneVM(ctx context.Context, vm *object.VirtualMachine, clonePath string) error {

	dc := strings.Split(vm.InventoryPath, "/")[0]

	datacenter, err := v.finder.DatacenterOrDefault(ctx, dc)
	if err != nil {
		return err
	}

	v.finder.SetDatacenter(datacenter)

	resourcePool, err := vm.ResourcePool(ctx)
	if err != nil {
		return err
	}

	// use path, not filepath so the windows stembuild executable
	//	still respects vsphere's forward slash scheme
	folder, err := v.finder.FolderOrDefault(ctx, path.Dir(clonePath))
	if err != nil {
		return err
	}

	ref := resourcePool.Reference()

	config := types.VirtualMachineCloneSpec{
		Location: types.VirtualMachineRelocateSpec{
			Pool: &ref,
		},
		PowerOn: true,
	}

	task, err := vm.Clone(ctx, folder, path.Base(clonePath), config)
	if err != nil {
		return err
	}

	err = task.WaitEx(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (v *VCenterManager) OperationsManager(ctx context.Context, vm *object.VirtualMachine) *guest.OperationsManager {
	return guest.NewOperationsManager(v.vimClient, vm.Reference())
}

func (v *VCenterManager) GuestManager(ctx context.Context, opsManager OpsManager, username, password string) (*guest_manager.GuestManager, error) {

	processManager, err := opsManager.ProcessManager(ctx)
	if err != nil {
		return nil, err
	}

	fileManager, err := opsManager.FileManager(ctx)
	if err != nil {
		return nil, err
	}
	auth := types.NamePasswordAuthentication{
		Username: username,
		Password: password,
	}
	return guest_manager.NewGuestManager(auth, processManager, fileManager, v.vimClient), nil
}
