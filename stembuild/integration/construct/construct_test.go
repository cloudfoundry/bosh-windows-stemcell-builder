package construct_test

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

const (
	constructOutputTimeout = 60 * time.Second
	shutdownTimeout        = 5 * time.Minute
)

var _ = Describe("stembuild construct", func() {
	var workingDir string

	BeforeEach(func() {
		var err error
		workingDir, err = os.Getwd()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterEach(func() {
		err := os.Remove(filepath.Join(workingDir, "LGPO.zip"))
		if err != nil {
			By(fmt.Sprintf("removing '%s/LGPO.zip' failed: %s", workingDir, err))
		}
	})

	Context("run successfully", func() {
		BeforeEach(func() {
			err := CopyFile(filepath.Join(workingDir, "assets", "LGPO.zip"), filepath.Join(workingDir, "LGPO.zip"))
			Expect(err).ToNot(HaveOccurred())
		})

		It("successfully exits when vm becomes powered off", func() {
			session := helpers.Stembuild(stembuildExecutable, "construct", "-vm-ip", conf.TargetIP, "-vm-username", conf.VMUsername, "-vm-password", conf.VMPassword, "-vcenter-url", conf.VCenterURL, "-vcenter-username", conf.VCenterUsername, "-vcenter-password", conf.VCenterPassword, "-vm-inventory-path", conf.VMInventoryPath, "-vcenter-ca-certs", conf.VCenterCACert)

			Eventually(session, shutdownTimeout).Should(Exit(0))
		})

		It("transfers LGPO and StemcellAutomation archives, unarchive them and execute automation script", func() {
			session := helpers.Stembuild(stembuildExecutable, "construct", "-vm-ip", conf.TargetIP, "-vm-username", conf.VMUsername, "-vm-password", conf.VMPassword, "-vcenter-url", conf.VCenterURL, "-vcenter-username", conf.VCenterUsername, "-vcenter-password", conf.VCenterPassword, "-vm-inventory-path", conf.VMInventoryPath, "-vcenter-ca-certs", conf.VCenterCACert)

			Eventually(session, shutdownTimeout).Should(Exit(0))
			Eventually(session.Out, constructOutputTimeout).Should(Say(`mock stemcell automation script executed`))
		})

		It("executes post-reboot automation script", func() {
			session := helpers.Stembuild(stembuildExecutable, "construct", "-vm-ip", conf.TargetIP, "-vm-username", conf.VMUsername, "-vm-password", conf.VMPassword, "-vcenter-url", conf.VCenterURL, "-vcenter-username", conf.VCenterUsername, "-vcenter-password", conf.VCenterPassword, "-vm-inventory-path", conf.VMInventoryPath, "-vcenter-ca-certs", conf.VCenterCACert)

			Eventually(session, shutdownTimeout).Should(Exit(0))
			Eventually(session.Out, constructOutputTimeout*5).Should(Say(`mock stemcell automation post-reboot script executed`))
		})

		It("extracts the WinRM BOSH powershell script and executes it successfully on the guest VM", func() {
			session := helpers.Stembuild(stembuildExecutable, "construct", "-vm-ip", conf.TargetIP, "-vm-username", conf.VMUsername, "-vm-password", conf.VMPassword, "-vcenter-url", conf.VCenterURL, "-vcenter-username", conf.VCenterUsername, "-vcenter-password", conf.VCenterPassword, "-vm-inventory-path", conf.VMInventoryPath, "-vcenter-ca-certs", conf.VCenterCACert)

			Eventually(session, shutdownTimeout).Should(Exit(0))
			Eventually(session.Out, constructOutputTimeout).Should(Say(`Attempting to enable WinRM on the guest vm...WinRm enabled on the guest VM`))
		})
	})

	It("fails with an appropriate error when LGPO is missing", func() {
		session := helpers.Stembuild(stembuildExecutable, "construct", "-vm-ip", conf.TargetIP, "-vm-username", conf.VMUsername, "-vm-password", conf.VMPassword, "-vcenter-url", conf.VCenterURL, "-vcenter-username", conf.VCenterUsername, "-vcenter-password", conf.VCenterPassword, "-vm-inventory-path", conf.VMInventoryPath, "-vcenter-ca-certs", conf.VCenterCACert)

		Eventually(session, constructOutputTimeout).Should(Exit(1))
		Eventually(session.Err).Should(Say(`Could not find LGPO.zip in the current directory`))
	})
})

func CopyFile(src string, dest string) error {
	input, err := os.ReadFile(src)
	if err != nil {
		By(fmt.Sprintf("Error reading %s: %s", src, err))
		return err
	}
	err = os.WriteFile(dest, input, 0644)
	if err != nil {
		By(fmt.Sprintf("Error creating %s: %s", dest, err))
		return err
	}

	return err
}
