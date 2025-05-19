package iaas_clients

import (
	"errors"
	"fmt"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clifakes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VcenterClient", func() {
	var (
		runner                  *iaas_clifakes.FakeCliRunner
		username, password, url string
		vcenterClient           *VcenterClient
		credentialUrl           string
		caCertFile              string
	)

	BeforeEach(func() {
		runner = &iaas_clifakes.FakeCliRunner{}
		username, password, caCertFile, url = "username", "password", "", "url"
		vcenterClient = NewVcenterClient(username, password, url, caCertFile, runner)
		credentialUrl = fmt.Sprintf("%s:%s@%s", username, password, url)
	})

	Context("NewVcenterClient", func() {
		It("url encodes credentials with special characters", func() {
			client := NewVcenterClient(`special\chars!user#`, `special^chars*pass`, url, caCertFile, runner)

			urlEncodedCredentials := `special%5Cchars%21user%23:special%5Echars%2Apass@url`
			expectedArgs := []string{"about", "-u", urlEncodedCredentials}

			runner.RunReturns(0)
			err := client.ValidateCredentials()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})
	})

	Context("A ca cert file is specified", func() {
		It("Passes the ca cert to govc", func() {
			vcenterClient = NewVcenterClient(username, password, url, "somefile.txt", runner)
			expectedArgs := []string{"about", "-u", credentialUrl, "-tls-ca-certs=somefile.txt"}

			runner.RunReturns(0)
			err := vcenterClient.ValidateCredentials()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})
	})

	Context("ValidateCredentials", func() {
		It("When the login credentials are correct, login is successful", func() {
			expectedArgs := []string{"about", "-u", credentialUrl}

			runner.RunReturns(0)
			err := vcenterClient.ValidateCredentials()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})

		It("When the login credentials are incorrect, login is a failure", func() {
			expectedArgs := []string{"about", "-u", credentialUrl}

			runner.RunReturns(1)
			err := vcenterClient.ValidateCredentials()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(HaveOccurred())
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
			Expect(err).To(MatchError("vcenter_client - invalid credentials for: username:REDACTED@url"))
		})
	})

	Context("validateUrl", func() {
		It("When the url is valid, there is no error", func() {
			expectedArgs := []string{"about", "-u", url}

			runner.RunReturns(0)
			err := vcenterClient.ValidateUrl()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})

		It("When the url is invalid, there is an error", func() {
			expectedArgs := []string{"about", "-u", url}

			runner.RunReturns(1)
			err := vcenterClient.ValidateUrl()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(HaveOccurred())
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
			Expect(err).To(MatchError("vcenter_client - unable to validate url: url"))
		})

		It("a validateUrl failure mentions the ca cert if one was specified", func() {

			vcenterClient = NewVcenterClient(username, password, url, "somefile.txt", runner)
			expectedArgs := []string{"about", "-u", url, "-tls-ca-certs=somefile.txt"}

			runner.RunReturns(1)
			err := vcenterClient.ValidateUrl()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(HaveOccurred())
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
			Expect(err).To(MatchError("vcenter_client - invalid ca certs or url: url"))
		})

		It("passes the ca cert to govc when specified", func() {

			vcenterClient = NewVcenterClient(username, password, url, "somefile.txt", runner)
			expectedArgs := []string{"about", "-u", url, "-tls-ca-certs=somefile.txt"}

			runner.RunReturns(0)
			err := vcenterClient.ValidateUrl()
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})
	})

	Context("FindVM", func() {
		It("If the VM path is valid, and the VM is found", func() {
			expectedArgs := []string{"find", "-u", credentialUrl, "-maxdepth=0", "validVMPath"}
			runner.RunReturns(0)
			err := vcenterClient.FindVM("validVMPath")
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
		})

		It("If the VM path is invalid", func() {
			expectedArgs := []string{"find", "-u", credentialUrl, "-maxdepth=0", "invalidVMPath"}
			runner.RunReturns(1)
			err := vcenterClient.FindVM("invalidVMPath")
			argsForRun := runner.RunArgsForCall(0)

			Expect(err).To(HaveOccurred())
			Expect(runner.RunCallCount()).To(Equal(1))
			Expect(argsForRun).To(Equal(expectedArgs))
			Expect(err).To(MatchError("vcenter_client - unable to find VM: invalidVMPath. Ensure your inventory path is formatted properly and includes \"vm\" in its path, example: /my-datacenter/vm/my-folder/my-vm-name"))
		})
	})

	Describe("RemoveDevice", func() {
		It("Removes a device from the given VM", func() {
			runner.RunReturns(0)
			err := vcenterClient.RemoveDevice("validVMPath", "device")

			Expect(err).To(Not(HaveOccurred()))
			expectedArgs := []string{"device.remove", "-u", credentialUrl, "-vm", "validVMPath", "device"}
			Expect(runner.RunArgsForCall(0)).To(Equal(expectedArgs))
		})

		It("Returns an error if VCenter reports a failure removing a device", func() {
			runner.RunReturns(1)
			err := vcenterClient.RemoveDevice("VMPath", "deviceName")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - deviceName could not be removed"))
		})
	})

	Describe("EjectCDrom", func() {
		It("Ejects a cd rom from the given VM", func() {
			runner.RunReturns(0)
			err := vcenterClient.EjectCDRom("validVMPath", "deviceName")

			Expect(err).To(Not(HaveOccurred()))
			expectedArgs := []string{"device.cdrom.eject", "-u", credentialUrl, "-vm", "validVMPath", "-device", "deviceName"}
			Expect(runner.RunArgsForCall(0)).To(Equal(expectedArgs))
		})

		It("Returns an error if VCenter reports a failure ejecting the cd rom", func() {
			runner.RunReturns(1)
			err := vcenterClient.EjectCDRom("VMPath", "deviceName")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - deviceName could not be ejected"))
		})
	})

	Context("ListDevices", func() {
		var govcListDevicesOutput = `ide-200            VirtualIDEController          IDE 0
ide-201            VirtualIDEController          IDE 1
ps2-300            VirtualPS2Controller          PS2 controller 0
pci-100            VirtualPCIController          PCI controller 0
sio-400            VirtualSIOController          SIO controller 0
floppy-8000        VirtualFloppy                 Remote
ethernet-0         VirtualE1000e                 internal-network
`

		It("returns a list of devices for the given VM", func() {
			runner.RunWithOutputReturns(govcListDevicesOutput, 0, nil)

			devices, err := vcenterClient.ListDevices("/path/to/vm")

			Expect(err).NotTo(HaveOccurred())
			Expect(devices).To(ConsistOf(
				"ide-200", "ide-201", "ps2-300", "pci-100", "sio-400", "floppy-8000", "ethernet-0",
			))

			Expect(runner.RunWithOutputArgsForCall(0)).To(Equal([]string{"device.ls", "-u", credentialUrl, "-vm", "/path/to/vm"}))
		})

		It("returns an error if govc runner returns non zero exit code", func() {
			runner.RunWithOutputReturns("", 1, nil)

			_, err := vcenterClient.ListDevices("/path/to/vm")

			Expect(err).To(MatchError("vcenter_client - failed to list devices in vCenter, govc exit code 1"))
		})

		It("returns an error if RunWithOutput encounters an error", func() {
			runner.RunWithOutputReturns("", 0, errors.New("some environment error"))

			_, err := vcenterClient.ListDevices("/path/to/vm")

			Expect(err).To(MatchError("vcenter_client - failed to parse list of devices. Err: some environment error"))
		})

		It("returns govc exit code error, when both govc exit code is non zero and RunWithOutput encounters an error", func() {
			runner.RunWithOutputReturns("", 1, errors.New("some environment error"))

			_, err := vcenterClient.ListDevices("/path/to/vm")

			Expect(err).To(MatchError("vcenter_client - failed to list devices in vCenter, govc exit code 1"))
		})
	})

	Context("ExportVM", func() {
		var destinationDir string
		BeforeEach(func() {
			destinationDir = GinkgoT().TempDir() // automatically cleaned up
		})

		It("exports the VM to local machine from vcenter using vm inventory path", func() {
			expectedArgs := []string{"export.ovf", "-u", credentialUrl, "-sha", "1", "-vm", "validVMPath", destinationDir}
			runner.RunReturns(0)
			err := vcenterClient.ExportVM("validVMPath", destinationDir)

			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunCallCount()).To(Equal(1))

			argsForRun := runner.RunArgsForCall(0)
			Expect(argsForRun).To(Equal(expectedArgs))
		})

		It("Returns an error message if ExportVM fails to export the VM", func() {
			vmInventoryPath := "validVMPath"
			expectedArgs := []string{"export.ovf", "-u", credentialUrl, "-sha", "1", "-vm", vmInventoryPath, destinationDir}
			runner.RunReturns(1)
			err := vcenterClient.ExportVM("validVMPath", destinationDir)

			expectedErrorMsg := fmt.Sprintf("vcenter_client - %s could not be exported", vmInventoryPath)
			Expect(err).To(HaveOccurred())
			Expect(runner.RunCallCount()).To(Equal(1))

			argsForRun := runner.RunArgsForCall(0)
			Expect(argsForRun).To(Equal(expectedArgs))
			Expect(err.Error()).To(Equal(expectedErrorMsg))
		})

		It("prints an appropriate error message if the given directory doesn't exist", func() {
			err := vcenterClient.ExportVM("validVMPath", "/FooBar/stuff")
			Expect(err).To(HaveOccurred())

			Expect(err.Error()).To(Equal("vcenter_client - provided destination directory: /FooBar/stuff does not exist"))
		})
	})

	Describe("UploadArtifact", func() {
		It("Uploads artifact to the given vm", func() {
			runner.RunReturns(0)
			err := vcenterClient.UploadArtifact("validVMPath", "artifact", "C:\\provision\\artifact", "user", "pass")

			Expect(err).To(Not(HaveOccurred()))
			expectedArgs := []string{"guest.upload", "-u", credentialUrl, "-f", "-l", "user:pass", "-vm", "validVMPath", "artifact", "C:\\provision\\artifact"}
			Expect(runner.RunArgsForCall(0)).To(Equal(expectedArgs))
		})

		It("Returns an error if VCenter reports a failure uploading the artifact", func() {
			runner.RunReturns(1)
			err := vcenterClient.UploadArtifact("validVMPath", "artifact", "C:\\provision\\artifact", "user", "pass")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - artifact could not be uploaded"))
		})
	})

	Describe("MakeDirectory", func() {
		It("Creates the directory on the vm", func() {
			runner.RunReturns(0)
			err := vcenterClient.MakeDirectory("validVMPath", "C:\\provision", "user", "pass")

			Expect(err).To(Not(HaveOccurred()))
			expectedArgs := []string{"guest.mkdir", "-u", credentialUrl, "-l", "user:pass", "-vm", "validVMPath", "-p", "C:\\provision"}
			Expect(runner.RunArgsForCall(0)).To(Equal(expectedArgs))
		})

		It("Returns an error if VCenter reports a failure making the directory", func() {
			runner.RunReturns(1)
			err := vcenterClient.MakeDirectory("validVMPath", "C:\\provision", "user", "pass")

			Expect(err).To(HaveOccurred())
			expectedArgs := []string{"guest.mkdir", "-u", credentialUrl, "-l", "user:pass", "-vm", "validVMPath", "-p", "C:\\provision"}
			Expect(runner.RunArgsForCall(0)).To(Equal(expectedArgs))

			Expect(err).To(MatchError("vcenter_client - directory `C:\\provision` could not be created"))
		})
	})

	Describe("Start", func() {
		It("runs the command on the vm", func() {
			runner.RunWithOutputReturns("1856\n", 0, nil) // govc add '\n' to the output
			pid, err := vcenterClient.Start("validVMPath", "user", "pass", "command", "arg1", "arg2", "arg3")

			Expect(err).To(Not(HaveOccurred()))
			Expect(pid).To(Equal("1856"))
			expectedArgs := []string{"guest.start", "-u", credentialUrl, "-l", "user:pass", "-vm", "validVMPath", "command", "arg1", "arg2", "arg3"}
			Expect(runner.RunWithOutputCallCount()).To(Equal(1))
			Expect(runner.RunWithOutputArgsForCall(0)).To(Equal(expectedArgs))
		})
		It("returns an error when RunWithOutput fails", func() {
			runner.RunWithOutputReturns("", 0, errors.New("error"))
			_, err := vcenterClient.Start("validVMPath", "user", "pass", "command2", "arg1", "arg2", "arg3")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - failed to run 'command2': error"))

		})
		It("returns an error when RunWithOutput returns an errCode", func() {
			runner.RunWithOutputReturns("", 1, nil)
			_, err := vcenterClient.Start("validVMPath", "user", "pass", "command2", "arg1", "arg2", "arg3")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - 'command2' returned exit code: 1"))
		})
	})

	Describe("WaitForExit", func() {
		// Sample output came from running `govc guest.ps` with the JSON flag set
		const sampleOutput = `{"ProcessInfo":[{"Name":"powershell.exe","Pid":1296,"Owner":"Administrator","CmdLine":"\"c:\\Windows\\System32\\WindowsPowershell\\v1.0\\powershell.exe\" dir","StartTime":"2019-03-26T18:33:31Z","EndTime":"2019-03-26T18:33:34Z","ExitCode":42}]}`
		const sampleOutputPidNotFound = `{"ProcessInfo":null}`
		const sampleOutputBadJson = `bad bad json format`

		It("returns the process' exit code upon success", func() {
			runner.RunWithOutputReturns(sampleOutput, 0, nil)
			exitCode, err := vcenterClient.WaitForExit("validVMPath", "user", "pass", "1296")

			Expect(err).To(Not(HaveOccurred()))
			Expect(exitCode).To(Equal(42))
			expectedArgs := []string{"guest.ps", "-u", credentialUrl, "-l", "user:pass", "-vm", "validVMPath", "-p", "1296", "-X", "-json"}
			Expect(runner.RunWithOutputCallCount()).To(Equal(1))
			Expect(runner.RunWithOutputArgsForCall(0)).To(Equal(expectedArgs))
		})

		It("returns an error if the process ID cannot be found", func() {
			runner.RunWithOutputReturns(sampleOutputPidNotFound, 0, nil)
			_, err := vcenterClient.WaitForExit("validVMPath", "user", "pass", "1296")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - couldn't get exit code for PID 1296"))
		})

		It("returns an error if a malformed json is returned", func() {
			runner.RunWithOutputReturns(sampleOutputBadJson, 0, nil)
			_, err := vcenterClient.WaitForExit("validVMPath", "user", "pass", "1296")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - received bad JSON output for PID 1296: bad bad json format"))

		})

		It("returns an error when RunWithOutput fails", func() {
			runner.RunWithOutputReturns(sampleOutput, 0, errors.New("bad command error"))
			_, err := vcenterClient.WaitForExit("validVMPath", "user", "pass", "3369")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - failed to fetch exit code for PID 3369: bad command error"))

		})

		It("returns an error when RunWithOutput returns an errCode", func() {
			runner.RunWithOutputReturns(sampleOutput, 20, nil)
			_, err := vcenterClient.WaitForExit("validVMPath", "user", "pass", "11678")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - fetching PID 11678 returned with exit code: 20"))
		})
	})

	Describe("IsPoweredOff", func() {
		It("Uses vm.info correctly to get power state", func() {
			expectedArgs := []string{"vm.info", "-u", credentialUrl, "validVMPath"}
			runner.RunWithOutputReturns("some result", 0, nil)

			_, err := vcenterClient.IsPoweredOff("validVMPath")
			argsForRun := runner.RunWithOutputArgsForCall(0)

			Expect(err).To(Not(HaveOccurred()))
			Expect(argsForRun).To(Not(ContainElement("-vm.ipath")))
			Expect(argsForRun).To(Equal(expectedArgs))

		})
		It("Gets the power state of the vm and returns false when vm is not powered off", func() {
			runner.RunWithOutputReturns("Power state:  poweredOn", 0, nil)
			out, err := vcenterClient.IsPoweredOff("validVMPath")

			Expect(out).To(BeFalse())
			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunWithOutputCallCount()).To(Equal(1))
		})
		It("Gets the power state of the vm and returns true when the vm is powered off", func() {
			runner.RunWithOutputReturns("Power state:  poweredOff", 0, nil)
			out, err := vcenterClient.IsPoweredOff("validVMPath")

			Expect(out).To(BeTrue())
			Expect(err).To(Not(HaveOccurred()))
			Expect(runner.RunWithOutputCallCount()).To(Equal(1))
		})

		It("Returns an exit code error if the runner returns a non zero exit code", func() {
			runner.RunWithOutputReturns("", 1, nil)
			_, err := vcenterClient.IsPoweredOff("validVMPath")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - failed to get vm info, govc exit code: 1"))
		})

		It("Returns an error if VCenter reports a failure getting the power state", func() {
			runner.RunWithOutputReturns("", 0, errors.New("some power state issue"))
			_, err := vcenterClient.IsPoweredOff("validVMPath")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - failed to determine vm power state: some power state issue"))
		})

		It("Returns an exit code error if the runner returns a non zero exit code and VCenter reports a failure getting the power state", func() {
			runner.RunWithOutputReturns("", 1, errors.New("some power state issue"))
			_, err := vcenterClient.IsPoweredOff("validVMPath")

			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - failed to get vm info, govc exit code: 1"))
		})
	})

})
