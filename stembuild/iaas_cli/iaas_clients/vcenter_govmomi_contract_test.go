package iaas_clients

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/guest_manager"
	vcenterclientfactory "github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
)

func envMustExist(variableName string) string {
	result := os.Getenv(variableName)
	if result == "" {
		Fail(fmt.Sprintf("%s must be set", variableName))
	}

	return result
}

var _ = Describe("VcenterClient", func() {
	Describe("StartProgram", func() {

		var (
			managerFactory *vcenterclientfactory.ManagerFactory
			factoryConfig  *vcenterclientfactory.FactoryConfig
		)

		BeforeEach(func() {

			factoryConfig = &vcenterclientfactory.FactoryConfig{
				VCenterServer: envMustExist(VcenterUrl),
				Username:      envMustExist(VcenterUsername),
				Password:      envMustExist(VcenterPassword),
				ClientCreator: &vcenterclientfactory.ClientCreator{},
				FinderCreator: &vcenterclientfactory.GovmomiFinderCreator{},
			}

			managerFactory = &vcenterclientfactory.ManagerFactory{}
		})

		ExpectProgramToStartAndExitSuccessfully := func() {

			ctx := context.TODO()

			vCenterManager, err := managerFactory.VCenterManager(ctx)
			Expect(err).ToNot(HaveOccurred())

			err = vCenterManager.Login(ctx)
			Expect(err).ToNot(HaveOccurred())

			vm, err := vCenterManager.FindVM(ctx, TestVmPath)
			Expect(err).ToNot(HaveOccurred())

			opsManager := vCenterManager.OperationsManager(ctx, vm)
			guestManager, err := vCenterManager.GuestManager(ctx, opsManager, envMustExist(TestVmUsername), envMustExist(TestVmPassword))
			Expect(err).ToNot(HaveOccurred())

			time.Sleep(10 * time.Second)

			powershell := "C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"
			pid, err := guestManager.StartProgramInGuest(ctx, powershell, "Exit 59")
			Expect(err).ToNot(HaveOccurred())

			exitCode, err := guestManager.ExitCodeForProgramInGuest(ctx, pid)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitCode).To(Equal(int32(59)))
		}

		Context("Use root cert implicitly", func() {
			It("Starts a program and returns its exit code", func() {
				factoryConfig.RootCACertPath = ""
				managerFactory.SetConfig(*factoryConfig)
				ExpectProgramToStartAndExitSuccessfully()
			})
		})

		Context("A factory is given a proper CA cert", func() {
			It("Starts a program and returns its exit code", func() {
				cert := os.Getenv(VcenterCACert)
				if cert == "" {
					Skip("export VCENTER_CA_CERT=<a valid ca cert> to run this test")
				}

				tmpDir := GinkgoT().TempDir() // automatically cleaned up
				f, err := os.CreateTemp(tmpDir, "valid-cert")
				Expect(err).ToNot(HaveOccurred())

				_, err = f.WriteString(cert)
				Expect(err).ToNot(HaveOccurred())

				err = f.Close()
				Expect(err).ToNot(HaveOccurred())

				factoryConfig.RootCACertPath = f.Name()
				managerFactory.SetConfig(*factoryConfig)

				ExpectProgramToStartAndExitSuccessfully()
			})
		})

		Context("A factory is given an improper CA cert", func() {
			It("fails to create a vcenter manager", func() {
				workingDir, err := os.Getwd()
				Expect(err).NotTo(HaveOccurred())
				fakeCertPath := filepath.Join(workingDir, "fixtures", "fakecert")

				factoryConfig.RootCACertPath = fakeCertPath
				managerFactory.SetConfig(*factoryConfig)

				ctx := context.TODO()
				_, err = managerFactory.VCenterManager(ctx)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("cannot be used as a trusted CA certificate"))
			})
		})
	})

	Describe("DownloadFileFromGuest", func() {
		var (
			managerFactory   *vcenterclientfactory.ManagerFactory
			factoryConfig    *vcenterclientfactory.FactoryConfig
			fileToDownload   string
			expectedContents string
			guestManager     *guest_manager.GuestManager
		)

		BeforeEach(func() {
			factoryConfig = &vcenterclientfactory.FactoryConfig{
				VCenterServer: envMustExist(VcenterUrl),
				Username:      envMustExist(VcenterUsername),
				Password:      envMustExist(VcenterPassword),
				ClientCreator: &vcenterclientfactory.ClientCreator{},
				FinderCreator: &vcenterclientfactory.GovmomiFinderCreator{},
			}
			managerFactory = &vcenterclientfactory.ManagerFactory{}
			factoryConfig.RootCACertPath = ""
			managerFactory.SetConfig(*factoryConfig)

			fileToDownload = "C:\\Windows\\dummy.txt"
			expectedContents = "infinite content"

			ctx := context.TODO()
			vCenterManager, err := managerFactory.VCenterManager(ctx)
			Expect(err).ToNot(HaveOccurred())

			err = vCenterManager.Login(ctx)
			Expect(err).ToNot(HaveOccurred())

			vm, err := vCenterManager.FindVM(ctx, TestVmPath)
			Expect(err).ToNot(HaveOccurred())

			opsManager := vCenterManager.OperationsManager(ctx, vm)
			guestManager, err = vCenterManager.GuestManager(ctx, opsManager, envMustExist(TestVmUsername), envMustExist(TestVmPassword))
			Expect(err).ToNot(HaveOccurred())

			time.Sleep(10 * time.Second)
		})

		Context("specified file exists", func() {
			BeforeEach(func() {
				ctx := context.TODO()

				powershell := "C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"
				pid, err := guestManager.StartProgramInGuest(ctx, powershell, fmt.Sprintf("'%s' | Set-Content %s", expectedContents, fileToDownload))
				Expect(err).ToNot(HaveOccurred())

				exitCode, err := guestManager.ExitCodeForProgramInGuest(ctx, pid)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitCode).To(Equal(int32(0)))
			})

			It("downloads the file", func() {
				ctx := context.TODO()
				fileContents, _, err := guestManager.DownloadFileInGuest(ctx, fileToDownload)
				Expect(err).NotTo(HaveOccurred())

				Eventually(BufferReader(fileContents)).Should(Say(expectedContents))

			})

			AfterEach(func() {
				ctx := context.TODO()

				powershell := "C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"
				pid, err := guestManager.StartProgramInGuest(ctx, powershell, fmt.Sprintf("rm %s", fileToDownload))
				Expect(err).ToNot(HaveOccurred())

				exitCode, err := guestManager.ExitCodeForProgramInGuest(ctx, pid)
				Expect(err).ToNot(HaveOccurred())
				Expect(exitCode).To(Equal(int32(0)))
			})
		})

		Context("specified file does not exist", func() {
			It("returns an error", func() {
				ctx := context.TODO()
				_, _, err := guestManager.DownloadFileInGuest(ctx, fileToDownload)
				Expect(err.Error()).To(ContainSubstring("vcenter_client - unable to download file"))
			})
		})
	})
})
