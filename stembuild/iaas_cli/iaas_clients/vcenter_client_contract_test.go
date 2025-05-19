package iaas_clients

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"
	vcenterclientfactory "github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VcenterManager", func() {

	Context("vcsim server with special character credentials", func() {
		var (
			cmd             *exec.Cmd
			vCenterUsername string
			vCenterPassword string
			vCenterUrl      string
			certPath        string
			keyPath         string
		)

		BeforeEach(func() {
			if runtime.GOOS != "windows" {

				workingDir, err := os.Getwd()
				Expect(err).NotTo(HaveOccurred())
				certPath = filepath.Join(workingDir, "fixtures", "dummycert")
				keyPath = filepath.Join(workingDir, "fixtures", "dummykey")

				vcsimBinary := filepath.Join(os.Getenv("GOPATH"), "bin", "vcsim")

				vCenterUsername = `user\name!#`
				vCenterPassword = `password\!#!`
				vCenterUrl = "127.0.0.1:8989/sdk"
				cmd = exec.Command(vcsimBinary, "-username", vCenterUsername, "-password", vCenterPassword, "-tlscert", certPath, "-tlskey", keyPath)

				err = cmd.Start()
				Expect(err).ToNot(HaveOccurred())

				time.Sleep(3 * time.Second) // the vcsim server needs a moment to come up
			}
		})

		AfterEach(func() {
			if runtime.GOOS != "windows" && cmd != nil {
				err := cmd.Process.Kill()
				Expect(err).ToNot(HaveOccurred())
			}
		})

		Context("VCenterManager.Login", func() {
			It("succeeds", func() {
				if runtime.GOOS == "windows" {
					Skip("windows cannot run a vcsim server")
				}

				factoryConfig := &vcenterclientfactory.FactoryConfig{
					VCenterServer:  vCenterUrl,
					Username:       vCenterUsername,
					Password:       vCenterPassword,
					ClientCreator:  &vcenterclientfactory.ClientCreator{},
					FinderCreator:  &vcenterclientfactory.GovmomiFinderCreator{},
					RootCACertPath: certPath,
				}

				managerFactory := &vcenterclientfactory.ManagerFactory{
					Config: *factoryConfig,
				}

				ctx := context.TODO()

				vCenterManager, err := managerFactory.VCenterManager(ctx)
				Expect(err).ToNot(HaveOccurred())

				err = vCenterManager.Login(ctx)
				Expect(err).ToNot(HaveOccurred())

			})
		})

		Context("govc_cli client login", func() {
			It("Succeeds", func() {
				if runtime.GOOS == "windows" {
					Skip("windows cannot run a vcsim server")
				}
				runner := &iaas_cli.GovcRunner{}
				client := NewVcenterClient(vCenterUsername, vCenterPassword, vCenterUrl, certPath, runner)

				err := client.ValidateCredentials()
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})
})
