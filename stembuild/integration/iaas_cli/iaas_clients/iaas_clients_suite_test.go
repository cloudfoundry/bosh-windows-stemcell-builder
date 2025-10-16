package iaas_clients_test

import (
	"context"
	"fmt"
	"os"
	"runtime"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/vmware/govmomi/object"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
)

func TestIaasClients(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "IaasClients Suite")
}

const (
	VcenterUrl      = "VCENTER_BASE_URL"
	VcenterUsername = "VCENTER_USERNAME"
	VcenterPassword = "VCENTER_PASSWORD"
	VmFolder        = "VM_FOLDER"
	TestVmName      = "CONTRACT_TEST_VM_NAME"
	VcenterCACert   = "VCENTER_CA_CERT"
	TestVmPassword  = "CONTRACT_TEST_VM_PASSWORD"
	TestVmUsername  = "CONTRACT_TEST_VM_USERNAME"
)

var (
	ctx = context.TODO()

	clonedVmPath string
	clonedVm     *object.VirtualMachine
)

var _ = BeforeSuite(func() {
	if runtime.GOOS == "windows" {
		Skip("Skipping test on Windows")
	}

	managerFactory := &vcenter_manager.ManagerFactory{
		Config: vcenter_manager.FactoryConfig{
			VCenterServer: envMustExist(VcenterUrl),
			Username:      envMustExist(VcenterUsername),
			Password:      envMustExist(VcenterPassword),
			ClientCreator: &vcenter_manager.ClientCreator{},
			FinderCreator: &vcenter_manager.GovmomiFinderCreator{},
		},
	}

	vCenterManager, err := managerFactory.VCenterManager(ctx)
	Expect(err).ToNot(HaveOccurred())

	err = vCenterManager.Login(ctx)
	Expect(err).ToNot(HaveOccurred())

	vmFolder := envMustExist(VmFolder)
	testVmName := envMustExist(TestVmName)
	testVmPath := fmt.Sprintf("%s/%s", vmFolder, testVmName)

	vmToClone, err := vCenterManager.FindVM(ctx, testVmPath)
	Expect(err).ToNot(HaveOccurred())

	clonedVmPath = fmt.Sprintf("%s-%s", testVmPath, time.Now().Format("2006-01-02T15h04s05"))

	err = vCenterManager.CloneVM(ctx, vmToClone, clonedVmPath)
	Expect(err).ToNot(HaveOccurred())

	time.Sleep(30 * time.Second)

	clonedVm, err = vCenterManager.FindVM(ctx, clonedVmPath)
	Expect(err).ToNot(HaveOccurred())
})

var _ = AfterSuite(func() {
	if clonedVm != nil {
		task, err := clonedVm.PowerOff(ctx)
		Expect(err).ToNot(HaveOccurred())
		err = task.WaitEx(ctx)
		Expect(err).ToNot(HaveOccurred())

		task, err = clonedVm.Destroy(ctx)
		Expect(err).ToNot(HaveOccurred())
		err = task.WaitEx(ctx)
		Expect(err).ToNot(HaveOccurred())
	}
})

func envMustExist(variableName string) string {
	result := os.Getenv(variableName)
	if result == "" {
		Fail(fmt.Sprintf("%s must be set", variableName))
	}

	return result
}
