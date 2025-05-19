package iaas_cli_test

import (
	"strings"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("GovcCli", func() {
	Describe("RunWithOutputs", func() {
		var runner iaas_cli.GovcRunner

		BeforeEach(func() {
			runner = iaas_cli.GovcRunner{}
		})

		It("lists the devices for a known VCenter VM", func() {
			out, _, err := runner.RunWithOutput([]string{"device.ls", "-vm", targetVMPath, "-u", vCenterCredentialUrl})

			Expect(err).NotTo(HaveOccurred())
			devices := strings.Split(`pci-100            VirtualPCIController          PCI controller 0
ide-200            VirtualIDEController          IDE 0
ide-201            VirtualIDEController          IDE 1
ps2-300            VirtualPS2Controller          PS2 controller 0
sio-400            VirtualSIOController          SIO controller 0
video-500          VirtualMachineVideoCard       Video card
keyboard-600       VirtualKeyboard               Keyboard
pointing-700       VirtualPointingDevice         Pointing device; Device
disk-1000-0        VirtualDisk                   41,943,040 KB
lsilogic-sas-1000  VirtualLsiLogicSASController  LSI Logic SAS
ethernet-0         VirtualE1000e                 internal-network
vmci-12000         VirtualMachineVMCIDevice      Device on the virtual machine PCI bus that provides support for the virtual machine communication interface
ahci-15000         VirtualAHCIController         AHCI
cdrom-16000        VirtualCdrom                  Remote device
`, "\n")

			for _, device := range devices {
				Expect(out).Should(ContainSubstring(device))
			}
		})

		It("returns exit code 1, if VM doesn't exist", func() {
			out, exitCode, err := runner.RunWithOutput([]string{"device.ls", "-vm", "/vm/does/not/exist", "-u", vCenterCredentialUrl})
			Expect(err).NotTo(HaveOccurred())
			Expect(exitCode).To(Equal(1))
			Expect(out).To(Equal(""))
		})
	})
})
