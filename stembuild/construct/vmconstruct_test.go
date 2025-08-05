package construct_test

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/constructfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller/pollerfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"
)

var _ = Describe("construct_helpers", func() {
	var (
		fakeRemoteManager         *remotemanagerfakes.FakeRemoteManager
		vmConstruct               *construct.VMConstruct
		fakeVcenterClient         *constructfakes.FakeIaasClient
		fakeGuestManager          *constructfakes.FakeGuestManager
		fakeWinRMEnabler          *constructfakes.FakeWinRMEnabler
		fakePoller                *pollerfakes.FakePollerI
		fakeVersionGetter         *constructfakes.FakeVersionGetter
		fakeVMConnectionValidator *constructfakes.FakeVMConnectionValidator
		fakeRebootWaiter          *constructfakes.FakeRebootWaiterI
		fakeScriptExecutor        *constructfakes.FakeScriptExecutorI
		fakeSetupFlags            []string

		outBuf *Buffer
		errBuf *Buffer
	)

	BeforeEach(func() {
		fakeRemoteManager = &remotemanagerfakes.FakeRemoteManager{}
		fakeVcenterClient = &constructfakes.FakeIaasClient{}
		fakeGuestManager = &constructfakes.FakeGuestManager{}
		fakeWinRMEnabler = &constructfakes.FakeWinRMEnabler{}
		fakePoller = &pollerfakes.FakePollerI{}
		fakeVersionGetter = &constructfakes.FakeVersionGetter{}
		fakeVMConnectionValidator = &constructfakes.FakeVMConnectionValidator{}
		fakeRebootWaiter = &constructfakes.FakeRebootWaiterI{}
		fakeScriptExecutor = &constructfakes.FakeScriptExecutorI{}
		fakeSetupFlags = []string{"SomeFlag SomeValue", "OtherFlag OtherValue"}

		outBuf = NewBuffer()
		errBuf = NewBuffer()
		stembuildMessenger := messenger.NewStembuildMessenger(outBuf, errBuf)

		vmConstruct = construct.NewVMConstruct(
			context.TODO(),
			fakeRemoteManager,
			"fakeUser",
			"fakePass",
			"fakeVmPath",
			fakeVcenterClient,
			fakeGuestManager,
			fakeWinRMEnabler,
			fakeVMConnectionValidator,
			stembuildMessenger,
			fakePoller,
			fakeVersionGetter,
			fakeRebootWaiter,
			fakeScriptExecutor,
			fakeSetupFlags,
		)
		vmConstruct.RebootWaitTime = 0

		fakeGuestManager.StartProgramInGuestReturnsOnCall(0, 0, nil)
		fakeGuestManager.ExitCodeForProgramInGuestReturnsOnCall(0, 0, nil)
		versionBuffer := NewBuffer()
		_, err := versionBuffer.Write([]byte("dev"))
		Expect(err).NotTo(HaveOccurred())

		fakeGuestManager.DownloadFileInGuestReturns(versionBuffer, 3, nil)
		fakeGuestManager.StartProgramInGuestReturns(0, nil)
	})

	Describe("ScriptExecutor", func() {
		It("executes setup script with correct arguments", func() {
			e := construct.NewScriptExecutor(fakeRemoteManager)
			version := "11.11.11"
			err := e.ExecuteSetupScript(version, fakeSetupFlags)
			executeCommandCallArg := fakeRemoteManager.ExecuteCommandArgsForCall(0)

			Expect(err).NotTo(HaveOccurred())
			Expect(executeCommandCallArg).To(ContainSubstring("powershell"))
			Expect(executeCommandCallArg).To(ContainSubstring("Setup.ps1"))
			Expect(executeCommandCallArg).To(ContainSubstring(" -Version " + version))
			Expect(executeCommandCallArg).To(ContainSubstring(" -SomeFlag SomeValue"))
			Expect(executeCommandCallArg).To(ContainSubstring(" -OtherFlag OtherValue"))
		})

		It("executes post-reboot script with correct arguments", func() {
			e := construct.NewScriptExecutor(fakeRemoteManager)
			superLongTimeout := 24 * time.Hour
			err := e.ExecutePostRebootScript(superLongTimeout)
			executeCommandCallArg, timeout := fakeRemoteManager.ExecuteCommandWithTimeoutArgsForCall(0)

			Expect(err).NotTo(HaveOccurred())
			Expect(executeCommandCallArg).To(ContainSubstring("powershell"))
			Expect(executeCommandCallArg).To(ContainSubstring("PostReboot.ps1"))
			Expect(timeout).To(Equal(superLongTimeout))
		})

		It("returns an error when there is a powershell script execution error", func() {
			e := construct.NewScriptExecutor(fakeRemoteManager)
			superLongTimeout := 24 * time.Hour
			powershellErrorPrefix := errors.New(remotemanager.PowershellExecutionErrorMessage)
			powershellErr := fmt.Errorf("%s: %s", powershellErrorPrefix, "a command failed to run")
			fakeRemoteManager.ExecuteCommandWithTimeoutReturns(2, powershellErr)

			err := e.ExecutePostRebootScript(superLongTimeout)

			Expect(err).To(MatchError(powershellErr))
		})

		It("wraps a non-powershell execution error", func() {
			e := construct.NewScriptExecutor(fakeRemoteManager)
			superLongTimeout := 24 * time.Hour
			winRMError := errors.New("some EOF thing")

			fakeRemoteManager.ExecuteCommandWithTimeoutReturns(1, winRMError)

			err := e.ExecutePostRebootScript(superLongTimeout)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("winrm connection event"))
		})
	})

	Describe("PrepareVM", func() {
		Describe("can create provision directory", func() {
			It("creates it successfully", func() {
				err := vmConstruct.PrepareVM()

				Expect(err).ToNot(HaveOccurred())
				Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
				Eventually(outBuf).Should(Say("\nCreating provision dir on target VM...succeeded.\n"))
			})

			It("fails when the provision dir cannot be created", func() {
				mkDirError := errors.New("failed to create dir")
				fakeVcenterClient.MakeDirectoryReturns(mkDirError)

				err := vmConstruct.PrepareVM()

				Expect(fakeVcenterClient.MakeDirectoryCallCount()).To(Equal(1))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("failed to create dir"))
				Eventually(outBuf).ShouldNot(Say("\nCreating provision dir on target VM...succeeded.\n"))
			})
		})

		Describe("enable WinRM", func() {
			It("returns failure when it fails to enable winrm", func() {
				execError := errors.New("failed to enable winRM")
				fakeWinRMEnabler.EnableReturns(execError)

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("failed to enable winRM"))

				Expect(fakeWinRMEnabler.EnableCallCount()).To(Equal(1))
			})

			It("logs that winrm was successfully enabled", func() {
				err := vmConstruct.PrepareVM()

				Expect(err).NotTo(HaveOccurred())
				Eventually(outBuf).Should(Say("\nAttempting to enable WinRM on the guest vm...WinRm enabled on the guest VM\n"))
			})
		})

		Describe("connect to VM", func() {
			It("checks for WinRM connectivity after WinRM enabled", func() {
				var calls []string

				fakeWinRMEnabler.EnableCalls(func() error {
					calls = append(calls, "enableWinRMCall")
					return nil
				})

				fakeVMConnectionValidator.ValidateCalls(func() error {
					calls = append(calls, "validateVMConnCall")
					return nil
				})

				err := vmConstruct.PrepareVM()
				Expect(err).NotTo(HaveOccurred())

				Expect(calls[0]).To(Equal("enableWinRMCall"))
				Expect(calls[1]).To(Equal("validateVMConnCall"))
			})

			It("logs that it successfully validated the vm connection", func() {
				err := vmConstruct.PrepareVM()

				Expect(err).NotTo(HaveOccurred())
				Eventually(outBuf).Should(Say("\nValidating connection to vm...succeeded.\n"))
			})

		})

		Describe("can upload artifacts", func() {
			Context("Upload all artifacts correctly", func() {
				It("passes successfully", func() {

					err := vmConstruct.PrepareVM()
					Expect(err).ToNot(HaveOccurred())
					vmPath, artifact, dest, user, pass := fakeVcenterClient.UploadArtifactArgsForCall(0)
					Expect(artifact).To(Equal("./LGPO.zip"))
					Expect(vmPath).To(Equal("fakeVmPath"))
					Expect(dest).To(Equal("C:\\provision\\LGPO.zip"))
					Expect(user).To(Equal("fakeUser"))
					Expect(pass).To(Equal("fakePass"))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))
					Eventually(outBuf).Should(Say("\nTransferring ~20 MB to the Windows VM. Depending on your connection, the transfer may take 15-45 minutes\n"))

					Eventually(outBuf).Should(Say(fmt.Sprintf("\tUploading %s to target VM...succeeded.\n", "LGPO")))
					Eventually(outBuf).Should(Say(fmt.Sprintf("\tUploading %s to target VM...succeeded.\n", "stemcell preparation artifacts")))

					Eventually(outBuf).Should(Say("\nAll files have been uploaded.\n"))
				})
			})

			Context("Fails to upload one or more artifacts", func() {
				It("fails when it cannot upload LGPO", func() {
					uploadError := errors.New("failed to upload LGPO")
					fakeVcenterClient.UploadArtifactReturns(uploadError)

					err := vmConstruct.PrepareVM()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(Equal("failed to upload LGPO"))

					vmPath, artifact, _, _, _ := fakeVcenterClient.UploadArtifactArgsForCall(0)
					Expect(artifact).To(Equal("./LGPO.zip"))
					Expect(vmPath).To(Equal("fakeVmPath"))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(1))
					Eventually(outBuf).Should(Say(fmt.Sprintf("\tUploading %s to target VM...", "LGPO")))
					Eventually(outBuf).ShouldNot(Say(fmt.Sprintf("\tUploading %s to target VM...succeeded.\n", "LGPO")))
				})

				It("fails when it cannot upload Stemcell Automation scripts", func() {
					uploadError := errors.New("failed to upload stemcell automation")
					fakeVcenterClient.UploadArtifactReturnsOnCall(0, nil)
					fakeVcenterClient.UploadArtifactReturnsOnCall(1, uploadError)

					err := vmConstruct.PrepareVM()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(Equal("failed to upload stemcell automation"))

					vmPath, artifact, _, _, _ := fakeVcenterClient.UploadArtifactArgsForCall(0)
					Expect(artifact).To(Equal("./LGPO.zip"))
					Expect(vmPath).To(Equal("fakeVmPath"))
					vmPath, artifact, _, _, _ = fakeVcenterClient.UploadArtifactArgsForCall(1)
					Expect(artifact).To(Equal("./StemcellAutomation.zip"))
					Expect(vmPath).To(Equal("fakeVmPath"))
					Expect(fakeVcenterClient.UploadArtifactCallCount()).To(Equal(2))

					Eventually(outBuf).Should(Say(fmt.Sprintf("\tUploading %s to target VM...", "stemcell preparation artifacts")))
					Eventually(outBuf).ShouldNot(Say(fmt.Sprintf("\tUploading %s to target VM...succeeded.\n", "stemcell preparation artifacts")))
				})
			})
		})

		Describe("logs out users", func() {
			var rawLogoffCommand = `&{If([string]::IsNullOrEmpty($(Get-WmiObject win32_computersystem).username)) {Write-Host "No users logged in." } Else {Write-Host "Logging out user."; $(Get-WmiObject win32_operatingsystem).Win32Shutdown(0) 1> $null}}`

			It("returns success when active user is logged out", func() {
				fakeRemoteManager.ExecuteCommandReturnsOnCall(0, 0, nil)

				err := vmConstruct.PrepareVM()
				Expect(err).ToNot(HaveOccurred())
				command := fakeRemoteManager.ExecuteCommandArgsForCall(0)

				encodedCommand := construct.EncodePowershellCommand([]byte(rawLogoffCommand))
				Expect(command).To(ContainSubstring(encodedCommand))
				Expect(command).To(ContainSubstring("powershell.exe -EncodedCommand "))

				Eventually(outBuf).Should(Say("\nAttempting to logout any remote users...\n\nLogged out remote users\n"))
			})

			It("returns failure when it fails to execute a logout", func() {
				errorMessage := "unable to execute command"
				fakeRemoteManager.ExecuteCommandReturnsOnCall(0, 1, errors.New(errorMessage))

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring(errorMessage))
				Expect(err.Error()).To(ContainSubstring("log out remote user failed with exit code 1"))

				Eventually(outBuf).Should(Say("\nAttempting to logout any remote users...\n"))
				Eventually(outBuf).ShouldNot(Say("\nAttempting to logout any remote users...\n\nLogged out remote users\n"))
			})
		})

		Describe("can extract archives", func() {
			It("returns failure when it fails to extract archive", func() {
				extractError := errors.New("failed to extract archive")
				fakeRemoteManager.ExtractArchiveReturns(extractError)

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
				Expect(err.Error()).To(Equal("failed to extract archive"))
				Eventually(outBuf).Should(Say("\nExtracting artifacts..."))
				Eventually(outBuf).ShouldNot(Say("\nExtracting artifacts...succeeded.\n"))
			})

			It("returns success when it properly extracts archive", func() {
				fakeRemoteManager.ExtractArchiveReturns(nil)

				err := vmConstruct.PrepareVM()
				Expect(err).ToNot(HaveOccurred())
				Expect(fakeRemoteManager.ExtractArchiveCallCount()).To(Equal(1))
				source, destination := fakeRemoteManager.ExtractArchiveArgsForCall(0)
				Expect(source).To(Equal("C:\\provision\\StemcellAutomation.zip"))
				Expect(destination).To(Equal("C:\\provision\\"))

				Eventually(outBuf).Should(Say("\nExtracting artifacts...succeeded.\n"))
			})
		})

		Describe("can execute setup scripts", func() {
			It("returns failure when it fails to execute setup script", func() {
				execError := errors.New("failed to execute setup script")
				fakeScriptExecutor.ExecuteSetupScriptReturnsOnCall(0, execError)

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("failed to execute setup script"))

				Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))

				Eventually(outBuf).Should(Say("\nExecuting setup script 1 of 2...\n"))
				Eventually(outBuf).ShouldNot(Say("\nExecuting setup script 1 of 2...\n\nFinished executing setup script 1 of 2.\n"))
			})

			It("returns success when it properly executes the setup script", func() {
				stembuildVersion := "2019.123.456"
				fakeVersionGetter.GetVersionReturns(stembuildVersion)

				err := vmConstruct.PrepareVM()
				Expect(err).ToNot(HaveOccurred())

				Expect(fakeScriptExecutor.ExecuteSetupScriptCallCount()).To(Equal(1))

				version, setupFlags := fakeScriptExecutor.ExecuteSetupScriptArgsForCall(0)
				Expect(version).To(Equal(stembuildVersion))
				Expect(setupFlags).To(Equal(fakeSetupFlags))

				Eventually(outBuf).Should(Say("\nExecuting setup script 1 of 2...\n\nFinished executing setup script 1 of 2.\n"))
			})
		})

		Describe("can check if vm is rebooting", func() {
			It("waits for reboot finished after the setup script has been executed", func() {
				var calls []string

				fakeRebootWaiter.WaitForRebootFinishedCalls(func() error {
					calls = append(calls, "waitForRebootFinishedCall")
					return nil
				})

				fakeScriptExecutor.ExecuteSetupScriptCalls(func(version string, setupFlags []string) error {
					calls = append(calls, "executeSetupScriptCalls")
					return nil
				})

				err := vmConstruct.PrepareVM()
				Expect(err).NotTo(HaveOccurred())

				Expect(calls[0]).To(Equal("executeSetupScriptCalls"))
				Expect(calls[1]).To(Equal("waitForRebootFinishedCall"))

				Eventually(outBuf).Should(Say("\nThe reboot has started...\n\nThe reboot has finished.\n"))
			})

			It("returns failure when it cannot determine if VM is rebooting", func() {
				fakeRebootWaiter.WaitForRebootFinishedReturnsOnCall(0, errors.New("polling is hard"))

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("polling is hard"))

				Eventually(outBuf).Should(Say("\nThe reboot has started...\n"))
				Eventually(outBuf).ShouldNot(Say("\nThe reboot has started...\n\nThe reboot has finished.\n"))
			})

		})

		Describe("can execute post-reboot script", func() {
			It("checks that the reboot has completed before the post reboot script is executed", func() {
				var calls []string

				fakeRebootWaiter.WaitForRebootFinishedCalls(func() error {
					calls = append(calls, "waitForRebootFinishedCall")
					return nil
				})

				fakeScriptExecutor.ExecutePostRebootScriptCalls(func(duration time.Duration) error {
					calls = append(calls, "executePostRebootScriptCalls")
					return nil
				})

				err := vmConstruct.PrepareVM()
				Expect(err).NotTo(HaveOccurred())

				Expect(calls[0]).To(Equal("waitForRebootFinishedCall"))
				Expect(calls[1]).To(Equal("executePostRebootScriptCalls"))
			})

			It("waits for reboot", func() {
				err := vmConstruct.PrepareVM()

				Expect(err).NotTo(HaveOccurred())
				Expect(fakeRebootWaiter.WaitForRebootFinishedCallCount()).To(Equal(1))
			})

			It("returns error if waiting for reboot fails", func() {
				rebootWaitError := errors.New("reboot waiting failed :(")
				fakeRebootWaiter.WaitForRebootFinishedReturns(rebootWaitError)
				err := vmConstruct.PrepareVM()

				Expect(err).To(MatchError(rebootWaitError))

				Eventually(outBuf).Should(Say("\nThe reboot has started...\n"))
				Eventually(outBuf).ShouldNot(Say("\nThe reboot has started...\n\nThe reboot has finished.\n"))
			})

			It("runs post-reboot command", func() {
				err := vmConstruct.PrepareVM()

				Expect(err).NotTo(HaveOccurred())
				Expect(fakeScriptExecutor.ExecutePostRebootScriptCallCount()).To(Equal(1))

				Eventually(outBuf).Should(Say("\nExecuting setup script 2 of 2...\n\nFinished executing setup script 2 of 2.\n"))
			})

			It("returns error if running post-reboot command fails", func() {
				postRebootError := errors.New("failed to execute command")
				fakeScriptExecutor.ExecutePostRebootScriptReturnsOnCall(0, postRebootError)
				err := vmConstruct.PrepareVM()

				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring(postRebootError.Error()))
				Eventually(outBuf).Should(Say("\nExecuting setup script 2 of 2...\n"))
				Eventually(outBuf).ShouldNot(Say("\nExecuting setup script 2 of 2...\n\nFinished executing setup script 2 of 2.\n"))
			})

			It("logs but does not error on winrm, non-powershell errors", func() {
				winrmError := errors.New("winrm connection event: some EOF error")

				fakeScriptExecutor.ExecutePostRebootScriptReturnsOnCall(0, winrmError)
				err := vmConstruct.PrepareVM()
				Expect(err).NotTo(HaveOccurred())

				Eventually(outBuf).Should(Say(fmt.Sprintf("\n%s\n", winrmError)))
				Eventually(outBuf).ShouldNot(Say("\nFinished executing setup script 2 of 2.\n"))
			})
		})

		Describe("can check that the VM is powered off", func() {
			It("runs every minute and returns successfully if polling succeeds", func() {
				fakePoller.PollReturns(nil)

				fakeVcenterClient.IsPoweredOffReturnsOnCall(0, false, nil)
				fakeVcenterClient.IsPoweredOffReturnsOnCall(1, true, nil)
				fakeVcenterClient.IsPoweredOffReturnsOnCall(2, false, errors.New("checking for powered off is hard"))

				err := vmConstruct.PrepareVM()
				Expect(err).ToNot(HaveOccurred())
				Eventually(outBuf).Should(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))

				Expect(fakePoller.PollCallCount()).To(Equal(1))
				pollDuration, pollFunc := fakePoller.PollArgsForCall(0)

				Expect(pollDuration).To(Equal(1 * time.Minute))

				Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(0))
				Eventually(outBuf).ShouldNot(Say(" Still preparing VM...\n"))

				isPoweredOff, err := pollFunc()
				Expect(isPoweredOff).To(BeFalse())
				Expect(err).NotTo(HaveOccurred())
				Eventually(outBuf).Should(Say(" Still preparing VM...\n"))

				isPoweredOff, err = pollFunc()
				Expect(isPoweredOff).To(BeTrue())
				Expect(err).NotTo(HaveOccurred())
				//Expect(fakeMessenger.WaitingForShutdownCallCount()).To(Equal(2))

				_, err = pollFunc()
				Expect(err).To(MatchError("checking for powered off is hard"))
				//Expect(fakeMessenger.WaitingForShutdownCallCount()).To(Equal(2))

				Expect(fakeVcenterClient.IsPoweredOffCallCount()).To(Equal(3))
			})

			It("returns failure when it cannot determine VM power state", func() {
				errorString := "cannot determine VM state"
				fakePoller.PollReturnsOnCall(0, errors.New(errorString))

				err := vmConstruct.PrepareVM()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal(errorString))

				Eventually(outBuf).ShouldNot(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
			})
		})
	})
})
