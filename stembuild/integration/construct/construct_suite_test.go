package construct_test

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/concourse/pool-resource/out"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/vmware/govmomi/cli"
	_ "github.com/vmware/govmomi/cli/device"
	_ "github.com/vmware/govmomi/cli/importx"
	_ "github.com/vmware/govmomi/cli/vm"
	_ "github.com/vmware/govmomi/cli/vm/guest"
	_ "github.com/vmware/govmomi/cli/vm/snapshot"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

func TestConstruct(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Construct Suite")
}

const (
	VMNameVariable                    = "VM_NAME"
	VMUsernameVariable                = "VM_USERNAME"
	VMPasswordVariable                = "VM_PASSWORD"
	TargetVmIPVariable                = "TARGET_VM_IP"
	SkipCleanupVariable               = "SKIP_CLEANUP"
	vcenterFolderVariable             = "VM_FOLDER"
	vcenterAdminCredentialUrlVariable = "VCENTER_ADMIN_CREDENTIAL_URL"
	vcenterBaseURLVariable            = "VCENTER_BASE_URL"
	VcenterCACert                     = "VCENTER_CA_CERT"
	vcenterStembuildUsernameVariable  = "VCENTER_USERNAME"
	vcenterStembuildPasswordVariable  = "VCENTER_PASSWORD"
	StembuildVersionVariable          = "STEMBUILD_VERSION"
	VmSnapshotName                    = "integration-test-snapshot"
	powershell                        = "C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"
)

var (
	conf                      config
	tmpDir                    string
	lockParentDir             string
	lockPool                  out.LockPool
	lockDir                   string
	stembuildExecutable       string
	vcenterAdminCredentialUrl string
	pathToCACert              string
)

type config struct {
	TargetIP        string
	NetworkGateway  string
	SubnetMask      string
	VMUsername      string
	VMPassword      string
	VMName          string
	VMNetwork       string
	VCenterURL      string
	VCenterCACert   string
	VCenterUsername string
	VCenterPassword string
	VMInventoryPath string
}

var _ = SynchronizedBeforeSuite(func() []byte {
	var err error

	stembuildVersion := envMustExist(StembuildVersionVariable)
	stembuildExecutable, err = helpers.BuildStembuild(stembuildVersion)
	Expect(err).NotTo(HaveOccurred())

	vmUsername := envMustExist(VMUsernameVariable)
	vmPassword := envMustExist(VMPasswordVariable)
	targetVMIP := envMustExist(TargetVmIPVariable)
	vmName := envMustExist(VMNameVariable)

	vCenterUrl := envMustExist(vcenterBaseURLVariable)
	vcenterFolder := envMustExist(vcenterFolderVariable)
	vmInventoryPath := strings.Join([]string{vcenterFolder, vmName}, "/")
	vcenterAdminCredentialUrl = envMustExist(vcenterAdminCredentialUrlVariable)

	vCenterStembuildUser := envMustExist(vcenterStembuildUsernameVariable)
	vCenterStembuildPassword := envMustExist(vcenterStembuildPasswordVariable)

	rawCA := envMustExist(VcenterCACert)
	t, err := os.CreateTemp("", "ca-cert")
	Expect(err).ToNot(HaveOccurred())
	pathToCACert = t.Name()
	Expect(t.Close()).To(Succeed())
	err = os.WriteFile(pathToCACert, []byte(rawCA), 0666)
	Expect(err).ToNot(HaveOccurred())

	wd, err := os.Getwd()
	Expect(err).NotTo(HaveOccurred())
	tmpDir, err = os.MkdirTemp(wd, "construct-integration")
	Expect(err).NotTo(HaveOccurred())

	err = os.MkdirAll(tmpDir, 0755)
	Expect(err).NotTo(HaveOccurred())

	conf = config{
		TargetIP:        targetVMIP,
		VMUsername:      vmUsername,
		VMPassword:      vmPassword,
		VCenterCACert:   pathToCACert,
		VCenterURL:      vCenterUrl,
		VCenterUsername: vCenterStembuildUser,
		VCenterPassword: vCenterStembuildPassword,
		VMName:          vmName,
		VMInventoryPath: vmInventoryPath,
	}

	enableWinRM()
	powerOnVM()
	createVMSnapshot(VmSnapshotName)

	return nil
}, func(_ []byte) {
})

var _ = BeforeEach(func() {
	revertSnapshot(conf.VMInventoryPath, VmSnapshotName)
	waitForVmToBeReady(conf.TargetIP, conf.VMUsername, conf.VMPassword)
})

var _ = SynchronizedAfterSuite(func() {
	skipCleanup := strings.ToUpper(os.Getenv(SkipCleanupVariable))

	if skipCleanup != "TRUE" {
		deleteCommand := []string{
			"vm.destroy",
			fmt.Sprintf("-vm.ipath=%s", conf.VMInventoryPath),
			fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
			fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		}
		Eventually(func() int {
			return cli.Run(deleteCommand)
		}, 3*time.Minute, 10*time.Second).Should(BeZero())
		By("VM destroyed")
		if lockDir != "" {
			_, _, err := lockPool.ReleaseLock(lockDir)
			Expect(err).NotTo(HaveOccurred())

			childItems, err := os.ReadDir(lockParentDir)
			Expect(err).NotTo(HaveOccurred())

			for _, item := range childItems {
				if item.IsDir() && strings.HasPrefix(filepath.Base(item.Name()), "pool-resource") {
					By(fmt.Sprintf("Cleaning up temporary pool resource %s\n", item.Name()))
					os.RemoveAll(item.Name()) //nolint:errcheck
				}
			}
		}
	}

	os.RemoveAll(tmpDir) //nolint:errcheck
}, func() {
	if pathToCACert != "" {
		os.RemoveAll(pathToCACert) //nolint:errcheck
	}
})

func revertSnapshot(vmIpath string, snapshotName string) {
	By(fmt.Sprintf("Starting VM snapshot.revert: %s\n", snapshotName))

	snapshotCommand := []string{
		"snapshot.revert",
		fmt.Sprintf("-vm.ipath=%s", vmIpath),
		fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
		fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		snapshotName,
	}
	revertExitCode := runIgnoringOutput(snapshotCommand)
	Expect(revertExitCode).To(Equal(0), "Starting VM snapshot.revert failed")

	By("Started VM snapshot.revert")
}

func waitForVmToBeReady(vmIp string, vmUsername string, vmPassword string) {
	const vmReadyTimeout = 15 * time.Minute
	const vmReadySleepInterval = 1 * time.Minute

	By("Waiting for VM snapshot.revert ...")
	clientFactory := remotemanager.NewWinRmClientFactory(vmIp, vmUsername, vmPassword)
	rm := remotemanager.NewWinRM(vmIp, vmUsername, vmPassword, clientFactory)
	Expect(rm).ToNot(BeNil())

	start := time.Now()
	vmReady := false
	for !vmReady {
		if time.Since(start) > vmReadyTimeout {
			Fail(fmt.Sprintf("VM at %s failed to start", vmIp))
		}
		time.Sleep(vmReadySleepInterval)
		_, err := rm.ExecuteCommand(`powershell.exe "ls c:\windows 1>$null"`)
		if err != nil {
			By(fmt.Sprintf("VM not yet ready: %v", err))
		}
		vmReady = err == nil
	}

	By("VM snapshot.revert finished")
}

func envMustExist(variableName string) string {
	result := os.Getenv(variableName)
	if result == "" {
		Fail(fmt.Sprintf("%s must be set", variableName))
	}

	return result
}

func enableWinRM() {
	_, currentFile, _, _ := runtime.Caller(0)
	repositoryRoot := filepath.Dir(filepath.Dir(filepath.Dir(filepath.Dir(currentFile))))

	By("Enabling WinRM on the base image before integration tests...")
	winRMPowershellModule := filepath.Join(repositoryRoot, "modules", "BOSH.WinRM", "BOSH.WinRM.psm1")
	uploadCommand := []string{
		"guest.upload",
		fmt.Sprintf("-vm.ipath=%s", conf.VMInventoryPath),
		fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
		fmt.Sprintf("-l=%s:%s", conf.VMUsername, conf.VMPassword),
		fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		winRMPowershellModule,
		"C:\\Windows\\Temp\\BOSH.WinRM.psm1",
	}

	uploadExitCode := runIgnoringOutput(uploadCommand)
	Expect(uploadExitCode).To(Equal(0), fmt.Sprintf("There was an error uploading %s", winRMPowershellModule))
	By(fmt.Sprintf("WinRM '%s' uploaded", winRMPowershellModule))

	enableCommand := []string{
		"guest.start",
		fmt.Sprintf("-vm.ipath=%s", conf.VMInventoryPath),
		fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
		fmt.Sprintf("-l=%s:%s", conf.VMUsername, conf.VMPassword),
		fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		powershell,
		`-command`,
		`&{Import-Module C:\Windows\Temp\BOSH.WinRM.psm1; Enable-WinRM}`,
	}
	enableExitCode := runIgnoringOutput(enableCommand)
	Expect(enableExitCode).To(Equal(0), "There was an error enabling WinRM.")
	By("WinRM enabled.")
}

func createVMSnapshot(snapshotName string) {
	const vmSnapshotCreateTimeout = 30 * time.Second

	By(fmt.Sprintf("VM snapshot.create: '-vm.ipath=%s' 'name=%s'", conf.VMInventoryPath, snapshotName))
	snapshotCommand := []string{
		"snapshot.create",
		fmt.Sprintf("-vm.ipath=%s", conf.VMInventoryPath),
		fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
		fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		snapshotName,
	}
	exitCode := cli.Run(snapshotCommand)
	Expect(exitCode).To(Equal(0), "VM snapshot.create failed")

	By(fmt.Sprintf("VM snapshot.create started, waiting '%s'", vmSnapshotCreateTimeout))
	time.Sleep(vmSnapshotCreateTimeout)
	By(fmt.Sprintf("VM snapshot.create started, waiting '%s' ... DONE", vmSnapshotCreateTimeout))
}

func powerOnVM() {
	powerOnCommand := []string{
		"vm.power",
		fmt.Sprintf("-vm.ipath=%s", conf.VMInventoryPath),
		fmt.Sprintf("-u=%s", vcenterAdminCredentialUrl),
		fmt.Sprintf("-tls-ca-certs=%s", pathToCACert),
		"-on",
	}
	powerOnExitCode := runIgnoringOutput(powerOnCommand)
	Expect(powerOnExitCode).To(Equal(0), "VM power-on failed")
}

func runIgnoringOutput(args []string) int {
	oldStderr := os.Stderr
	oldStdout := os.Stdout

	_, w, _ := os.Pipe() //nolint:errcheck

	defer w.Close() //nolint:errcheck

	os.Stderr = w
	os.Stdout = w

	os.Stderr = os.NewFile(uintptr(syscall.Stderr), "/dev/null")

	exitCode := cli.Run(args)

	os.Stderr = oldStderr
	os.Stdout = oldStdout

	return exitCode
}
