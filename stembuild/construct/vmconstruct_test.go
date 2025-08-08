package construct_test

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/constructfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller/pollerfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"
)

type nonWaitingPoller struct{}

func (p *nonWaitingPoller) Poll(_ time.Duration, loopFunc func() (bool, error)) error {
	poll := true
	for poll {
		out, err := loopFunc()
		if err != nil {
			return err
		}
		poll = !out
	}
	return nil
}

var _ = Describe("construct_helpers", func() {
	var (
		outBuf *Buffer
		errBuf *Buffer

		testPoller          poller.PollerI
		useNonWaitingPoller bool

		ctx                       context.Context
		fakeRemoteManager         *remotemanagerfakes.FakeRemoteManager
		vmUsername                string
		vmPassword                string
		vmInventoryPath           string
		vmConstruct               *construct.VMConstruct
		fakeVcenterClient         *constructfakes.FakeIaasClient
		fakeGuestManager          *constructfakes.FakeGuestManager
		fakeWinRMEnabler          *constructfakes.FakeWinRMEnabler
		fakePoller                *pollerfakes.FakePollerI
		fakeVersionGetter         *constructfakes.FakeVersionGetter
		fakeVMConnectionValidator *constructfakes.FakeVMConnectionValidator
		stembuildMessenger        messenger.Messenger
		fakeRebootWaiter          *constructfakes.FakeRebootWaiterI
		fakeScriptExecutor        *constructfakes.FakeScriptExecutorI
		fakeSetupFlags            []string
	)

	BeforeEach(func() {
		outBuf = NewBuffer()
		errBuf = NewBuffer()

		ctx = context.TODO()
		fakeRemoteManager = &remotemanagerfakes.FakeRemoteManager{}
		vmUsername = "fakeUser"
		vmPassword = "fakePass"
		vmInventoryPath = "fakeVmPath"
		fakeVcenterClient = &constructfakes.FakeIaasClient{}
		fakeGuestManager = &constructfakes.FakeGuestManager{}
		fakeWinRMEnabler = &constructfakes.FakeWinRMEnabler{}
		fakePoller = &pollerfakes.FakePollerI{}
		fakeVersionGetter = &constructfakes.FakeVersionGetter{}
		fakeVMConnectionValidator = &constructfakes.FakeVMConnectionValidator{}
		stembuildMessenger = messenger.NewStembuildMessenger(outBuf, errBuf)
		fakeRebootWaiter = &constructfakes.FakeRebootWaiterI{}
		fakeScriptExecutor = &constructfakes.FakeScriptExecutorI{}
		fakeSetupFlags = []string{"SomeFlag SomeValue", "OtherFlag OtherValue"}

		useNonWaitingPoller = false
	})

	JustBeforeEach(func() {
		testPoller = fakePoller
		if useNonWaitingPoller {
			testPoller = &nonWaitingPoller{}
		}

		vmConstruct = construct.NewVMConstruct(
			ctx,
			fakeRemoteManager,
			vmUsername,
			vmPassword,
			vmInventoryPath,
			fakeVcenterClient,
			fakeGuestManager,
			fakeWinRMEnabler,
			fakeVMConnectionValidator,
			stembuildMessenger,
			testPoller,
			fakeVersionGetter,
			fakeRebootWaiter,
			fakeScriptExecutor,
			fakeSetupFlags,
		)
		vmConstruct.RebootWaitTime = 0
	})

	Describe("PrepareVM", func() {
		Describe("creates provision directory", func() {
			Context("when it fails", func() {
				var makeDirectoryErr error
				BeforeEach(func() {
					makeDirectoryErr = errors.New("fake-make-directory-error")
					fakeVcenterClient.MakeDirectoryReturns(makeDirectoryErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(makeDirectoryErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nCreating provision dir on target VM..."))
					Eventually(outBuf).ShouldNot(Say("\nCreating provision dir on target VM...succeeded.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nCreating provision dir on target VM...succeeded.\n"))
				})
			})
		})

		Describe("uploads LGPO.zip", func() {
			It("invokes the artifact uploader as expected", func() {
				Expect(vmConstruct.PrepareVM()).To(Succeed())

				actualVmInventoryPath, actualArtifact, actualDestination, actualVmUsername, actualVmPassword :=
					fakeVcenterClient.UploadArtifactArgsForCall(0)

				Expect(actualVmInventoryPath).To(Equal(vmInventoryPath))
				Expect(actualArtifact).To(Equal("./LGPO.zip"))
				Expect(actualDestination).To(Equal(`C:\provision\LGPO.zip`))
				Expect(actualVmUsername).To(Equal(vmUsername))
				Expect(actualVmPassword).To(Equal(vmPassword))
			})

			Context("when it fails", func() {
				var uploadLgpoErr error

				BeforeEach(func() {
					uploadLgpoErr = errors.New("fake-upload-lgpo-error")
					fakeVcenterClient.UploadArtifactReturnsOnCall(0, uploadLgpoErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(uploadLgpoErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(1))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\tUploading LGPO to target VM..."))
					Eventually(outBuf).ShouldNot(Say("\tUploading LGPO to target VM...succeeded.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\tUploading LGPO to target VM...succeeded.\n"))
				})
			})
		})

		Describe("uploads StemcellAutomation.zip", func() {
			It("invokes the artifact uploader as expected", func() {
				Expect(vmConstruct.PrepareVM()).To(Succeed())

				actualVmInventoryPath, actualArtifact, actualDestination, actualVmUsername, actualVmPassword :=
					fakeVcenterClient.UploadArtifactArgsForCall(1)

				Expect(actualVmInventoryPath).To(Equal(vmInventoryPath))
				Expect(actualArtifact).To(Equal("./StemcellAutomation.zip"))
				Expect(actualDestination).To(Equal(`C:\provision\StemcellAutomation.zip`))
				Expect(actualVmUsername).To(Equal(vmUsername))
				Expect(actualVmPassword).To(Equal(vmPassword))
			})

			Context("when it fails", func() {
				var uploadStemcellAutomationErr error

				BeforeEach(func() {
					uploadStemcellAutomationErr = errors.New("fake-upload-stemcell-automation-error")

					fakeVcenterClient.UploadArtifactReturnsOnCall(0, nil)
					fakeVcenterClient.UploadArtifactReturnsOnCall(1, uploadStemcellAutomationErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(uploadStemcellAutomationErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\tUploading stemcell preparation artifacts to target VM..."))
					Eventually(outBuf).ShouldNot(Say("\tUploading stemcell preparation artifacts to target VM...succeeded.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\tUploading stemcell preparation artifacts to target VM...succeeded.\n"))
				})
			})
		})

		Describe("enables WinRM", func() {
			Context("when it fails", func() {
				var enableErr error
				BeforeEach(func() {
					enableErr = errors.New("fake-enable-winrm-error")
					fakeWinRMEnabler.EnableReturns(enableErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(enableErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nAttempting to enable WinRM on the guest vm..."))
					Eventually(outBuf).ShouldNot(Say("WinRm enabled on the guest VM\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("WinRm enabled on the guest VM\n"))
				})
			})
		})

		Describe("validates VM connection", func() {
			Context("when it fails", func() {
				var validateErr error
				BeforeEach(func() {
					validateErr = errors.New("fake-validate-connection-error")
					fakeVMConnectionValidator.ValidateReturns(validateErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(validateErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nValidating connection to vm..."))
					Eventually(outBuf).ShouldNot(Say("\nValidating connection to vm...succeeded.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nValidating connection to vm...succeeded.\n"))
				})
			})
		})

		Describe("extracts artifacts", func() {
			Context("when it fails", func() {
				var extractErr error
				BeforeEach(func() {
					extractErr = errors.New("fake-extract-error")
					fakeRemoteManager.ExtractArchiveReturns(extractErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(extractErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nExtracting artifacts..."))
					Eventually(outBuf).ShouldNot(Say("\nExtracting artifacts...succeeded.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nExtracting artifacts...succeeded.\n"))
				})
			})
		})

		Describe("logs out users", func() {
			It("constructs the expected powershell command", func() {
				rawLogoffCommand := `&{If([string]::IsNullOrEmpty($(Get-WmiObject win32_computersystem).username)) {Write-Host "No users logged in." } Else {Write-Host "Logging out user."; $(Get-WmiObject win32_operatingsystem).Win32Shutdown(0) 1> $null}}`
				encodedCommand := construct.EncodePowershellCommand([]byte(rawLogoffCommand))

				expectedCommand := fmt.Sprintf("powershell.exe -EncodedCommand %s", encodedCommand)

				Expect(vmConstruct.PrepareVM()).To(Succeed())

				executeCommandArg := fakeRemoteManager.ExecuteCommandArgsForCall(0)
				Expect(executeCommandArg).To(Equal(expectedCommand))
			})

			Context("when it fails", func() {
				var executePowershellCommandErr error
				var executePowershellCommandExitCode int
				BeforeEach(func() {
					executePowershellCommandErr = errors.New("fake-execute-powershell-command-error")
					executePowershellCommandExitCode = 90210
					fakeRemoteManager.ExecuteCommandReturns(executePowershellCommandExitCode, executePowershellCommandErr)
				})

				It("returns an error wrapping the original that includes the exit code", func() {
					err := vmConstruct.PrepareVM()

					Expect(err.Error()).To(ContainSubstring(executePowershellCommandErr.Error()))
					Expect(err.Error()).To(ContainSubstring(fmt.Sprintf("log out remote user failed with exit code %d", executePowershellCommandExitCode)))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nAttempting to logout any remote users...\n"))
					Eventually(outBuf).ShouldNot(Say("\nAttempting to logout any remote users...\n\nLogged out remote users\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nAttempting to logout any remote users...\n\nLogged out remote users\n"))
				})
			})
		})

		Describe("executing setup script 1 of 2", func() {
			It("invokes the script with the expected args", func() {
				stembuildVersion := "2019.123.456"
				fakeVersionGetter.GetVersionReturns(stembuildVersion)

				Expect(vmConstruct.PrepareVM()).To(Succeed())

				version, setupFlags := fakeScriptExecutor.ExecuteSetupScriptArgsForCall(0)
				Expect(version).To(Equal(stembuildVersion))
				Expect(setupFlags).To(Equal(fakeSetupFlags))
			})

			Context("when it fails", func() {
				var executeSetupScriptErr error
				BeforeEach(func() {
					executeSetupScriptErr = errors.New("fake-execute-setup-script-error")
					fakeScriptExecutor.ExecuteSetupScriptReturns(executeSetupScriptErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(executeSetupScriptErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
					Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nExecuting setup script 1 of 2...\n"))
					Eventually(outBuf).ShouldNot(Say("\nExecuting setup script 1 of 2...\n\nFinished executing setup script 1 of 2.\n\nWinRM has been disconnected so the VM can reboot.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
					Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nExecuting setup script 1 of 2...\n\nFinished executing setup script 1 of 2.\n\nWinRM has been disconnected so the VM can reboot.\n"))
				})
			})
		})

		Describe("waiting for vm to reboot", func() {
			Context("when it fails", func() {
				var waitForRebootFinishedErr error
				BeforeEach(func() {
					waitForRebootFinishedErr = errors.New("fake-wait-for-reboot-finished-error")
					fakeRebootWaiter.WaitForRebootFinishedReturns(waitForRebootFinishedErr)
				})

				It("returns the error", func() {
					err := vmConstruct.PrepareVM()
					Expect(err).To(Equal(waitForRebootFinishedErr))
				})

				It("does not execute the next step", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
					Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(0))
				})

				It("it logs the attempt", func() {
					Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

					Eventually(outBuf).Should(Say("\nThe reboot has started...\n"))
					Eventually(outBuf).ShouldNot(Say("\nThe reboot has started...\n\nThe reboot has finished.\n"))
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
					Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nThe reboot has started...\n\nThe reboot has finished.\n"))
				})
			})
		})

		Describe("executing setup script 2 of 2", func() {
			BeforeEach(func() {
				fakePoller.PollStub = func(duration time.Duration, pollFunc func() (bool, error)) error {
					_, err := pollFunc()
					Expect(err).NotTo(HaveOccurred())
					return nil
				}
			})

			Context("script execution returns an error", func() {
				var executePostRebootScriptErr error

				Context("and the error contains 'winrm connection event'", func() {
					BeforeEach(func() {
						executePostRebootScriptErr = errors.New("winrm connection event: nothing-here-matters")
						fakeScriptExecutor.ExecutePostRebootScriptReturns(executePostRebootScriptErr)
					})

					It("executes the next step", func() {
						Expect(vmConstruct.PrepareVM()).To(Succeed())

						Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
						Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
						Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
						Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
						Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
						Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
						Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
						Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
						Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(1))
						Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(1))
					})

					It("logs but does not error on winrm, non-powershell errors", func() {
						Expect(vmConstruct.PrepareVM()).To(Succeed())

						Eventually(outBuf).Should(Say(fmt.Sprintf("\n%s\n", executePostRebootScriptErr)))
					})
				})

				Context("and the error DOES NOT contain 'winrm connection event'", func() {
					BeforeEach(func() {
						executePostRebootScriptErr = errors.New("fake-execute-post-reboot-script-error")
						fakeScriptExecutor.ExecutePostRebootScriptReturns(executePostRebootScriptErr)
					})

					It("returns an error wrapping the original", func() {
						err := vmConstruct.PrepareVM()

						Expect(err.Error()).To(Equal(fmt.Sprintf("failure in post-reboot script: %s", executePostRebootScriptErr)))
					})

					It("does not execute the next step", func() {
						Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

						Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
						Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
						Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
						Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
						Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
						Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
						Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
						Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
						Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(1))
						Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(0))
					})

					It("it logs the attempt", func() {
						Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

						Eventually(outBuf).Should(Say("\nExecuting setup script 2 of 2...\n"))
						Eventually(outBuf).ShouldNot(Say("\nExecuting setup script 2 of 2...\n\nFinished executing setup script 2 of 2.\n"))
					})
				})
			})

			Context("when it succeeds", func() {
				It("executes the next step", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
					Expect(fakeVMConnectionValidator.ValidateCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
					Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))
					Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
					Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(1))
					Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(1))
				})

				It("it logs success", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())

					Eventually(outBuf).Should(Say("\nExecuting setup script 2 of 2...\n\nFinished executing setup script 2 of 2.\n"))
				})
			})
		})

		Describe("polls the VM's powered off state", func() {
			Describe("poller invocation", func() {
				It("invokes the poller with the expected args", func() {
					Expect(vmConstruct.PrepareVM()).To(Succeed())
					Eventually(outBuf).Should(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))

					Expect(fakePoller.PollCallCount()).To(Equal(1))
					pollDuration, _ := fakePoller.PollArgsForCall(0)

					Expect(pollDuration).To(Equal(time.Minute))
				})
			})

			Describe("polled function", func() {
				BeforeEach(func() {
					useNonWaitingPoller = true
				})

				Context("when the VM fails to power off", func() {
					var isPoweredOffErr error

					BeforeEach(func() {
						isPoweredOffErr = errors.New("power-off-failed")
					})

					Context("on the first attempt", func() {
						BeforeEach(func() {
							fakeVcenterClient.IsPoweredOffReturns(false, isPoweredOffErr)
						})

						It("returns the error", func() {
							err := vmConstruct.PrepareVM()
							Expect(err).To(MatchError(isPoweredOffErr))
						})

						It("does not print subsequent logs", func() {
							Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

							Eventually(outBuf).ShouldNot(Say("Still preparing VM...\n"))
							Eventually(outBuf).ShouldNot(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
						})
					})

					Context("on a subsequent attempt", func() {
						BeforeEach(func() {
							fakeVcenterClient.IsPoweredOffReturnsOnCall(0, false, nil)
							fakeVcenterClient.IsPoweredOffReturnsOnCall(1, false, isPoweredOffErr)
						})

						It("returns the error", func() {
							err := vmConstruct.PrepareVM()
							Expect(err).To(MatchError(isPoweredOffErr))
						})

						It("logs a polling attempt", func() {
							Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

							Eventually(outBuf).Should(Say("Still preparing VM...\n"))
						})

						It("does not print subsequent logs", func() {
							Expect(vmConstruct.PrepareVM()).NotTo(Succeed())

							Eventually(outBuf).ShouldNot(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
						})
					})
				})

				Context("when the VM successfully powers off", func() {
					Context("on the first attempt", func() {
						BeforeEach(func() {
							fakeVcenterClient.IsPoweredOffReturnsOnCall(0, true, nil)
						})

						It("executes the is-powered-off func once", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(1))
						})

						It("does not log a polling attempt", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Eventually(outBuf).Should(Say("Still preparing VM...\n"))
						})

						It("prints subsequent logs", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Eventually(outBuf).ShouldNot(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
						})
					})

					Context("on a subsequent attempt", func() {
						BeforeEach(func() {
							fakeVcenterClient.IsPoweredOffReturnsOnCall(0, false, nil)
							fakeVcenterClient.IsPoweredOffReturnsOnCall(1, true, nil)
						})

						It("executes the is-powered-off func twice", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(2))
						})

						It("logs a polling attempt", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Eventually(outBuf).Should(Say("Still preparing VM...\n"))
						})

						It("prints subsequent logs", func() {
							Expect(vmConstruct.PrepareVM()).To(Succeed())

							Eventually(outBuf).ShouldNot(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
						})
					})
				})
			})
		})
	})
})
