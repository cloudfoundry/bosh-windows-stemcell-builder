package construct

import (
	"context"
	"os"

	"github.com/pkg/errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/archive"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"
)

type Factory struct {
}

func (f *Factory) New(config config.SourceConfig, vCenterManager commandparser.VCenterManager) (commandparser.VmConstruct, error) {
	runner := &iaas_cli.GovcRunner{}
	client := iaas_clients.NewVcenterClient(config.VCenterUsername, config.VCenterPassword, config.VCenterUrl, config.CaCertFile, runner)

	messenger := NewMessenger(os.Stdout)

	ctx := context.Background()
	err := vCenterManager.Login(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "Cannot complete login due to an incorrect vCenter user name or password")
	}

	vm, err := vCenterManager.FindVM(ctx, config.VmInventoryPath)
	if err != nil {
		return nil, err
	}

	opsManager := vCenterManager.OperationsManager(ctx, vm)

	guestManager, err := vCenterManager.GuestManager(ctx, opsManager, config.GuestVMUsername, config.GuestVMPassword)
	if err != nil {
		return nil, err
	}

	winRMManager := &WinRMManager{
		GuestManager: guestManager,
		Unarchiver:   &archive.Zip{},
	}
	versionGetter := version.NewVersionGetter()

	winRmClientFactory := remotemanager.NewWinRmClientFactory(config.GuestVmIp, config.GuestVMUsername, config.GuestVMPassword)
	remoteManager := remotemanager.NewWinRM(config.GuestVmIp, config.GuestVMUsername, config.GuestVMPassword, winRmClientFactory)

	vmConnectionValidator := &WinRMConnectionValidator{
		RemoteManager: remoteManager,
	}

	rebootPoller := &poller.Poller{}

	rebootChecker := remotemanager.NewRebootChecker(remoteManager)

	rebootWaiter := remotemanager.NewRebootWaiter(rebootPoller, rebootChecker)

	scriptExecutor := NewScriptExecutor(remoteManager)

	return NewVMConstruct(
		ctx,
		remoteManager,
		config.GuestVMUsername,
		config.GuestVMPassword,
		config.VmInventoryPath,
		client,
		guestManager,
		winRMManager,
		vmConnectionValidator,
		messenger,
		rebootPoller,
		versionGetter,
		rebootWaiter,
		scriptExecutor,
		config.SetupFlags,
	), nil
}
