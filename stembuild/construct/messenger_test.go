package construct_test

import (
	"fmt"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
)

var _ = Describe("Messenger", func() {
	var buf *Buffer

	BeforeEach(func() {
		buf = NewBuffer()
	})

	Describe("Enable WinRM messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.EnableWinRMStarted()

			Expect(buf).To(Say("\nAttempting to enable WinRM on the guest vm..."))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.EnableWinRMSucceeded()

			Expect(buf).To(Say("WinRm enabled on the guest VM\n"))
		})

		It("writes both WinRM messages on one line", func() {
			m := construct.NewMessenger(buf)
			m.EnableWinRMStarted()
			m.EnableWinRMSucceeded()

			Expect(buf).To(Say("Attempting to enable WinRM on the guest vm...WinRm enabled on the guest VM"))
		})
	})

	Describe("Validate VM connection messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ValidateVMConnectionStarted()

			Expect(buf).To(Say("\nValidating connection to vm..."))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ValidateVMConnectionSucceeded()

			Expect(buf).To(Say("succeeded.\n"))
		})

		It("writes both validate vm connection messages on one line", func() {
			m := construct.NewMessenger(buf)
			m.ValidateVMConnectionStarted()
			m.ValidateVMConnectionSucceeded()

			Expect(buf).To(Say("Validating connection to vm...succeeded."))
		})
	})

	Describe("Create provision directory messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.CreateProvisionDirStarted()

			Expect(buf).To(Say("\nCreating provision dir on target VM..."))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.CreateProvisionDirSucceeded()

			Expect(buf).To(Say("succeeded.\n"))
		})

		It("writes both messages on one line", func() {
			m := construct.NewMessenger(buf)
			m.CreateProvisionDirStarted()
			m.CreateProvisionDirSucceeded()

			Expect(buf).To(Say("\nCreating provision dir on target VM...succeeded.\n"))
		})
	})

	Describe("Upload artifacts messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.UploadArtifactsStarted()

			Expect(buf).To(Say("\nTransferring ~20 MB to the Windows VM. Depending on your connection, the transfer may take 15-45 minutes\n"))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.UploadArtifactsSucceeded()

			Expect(buf).To(Say("\nAll files have been uploaded.\n"))
		})
	})

	Describe("Extract artifact messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExtractArtifactsStarted()

			Expect(buf).To(Say("\nExtracting artifacts..."))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExtractArtifactsSucceeded()

			Expect(buf).To(Say("succeeded.\n"))
		})

		It("writes both messages on one line", func() {
			m := construct.NewMessenger(buf)
			m.ExtractArtifactsStarted()
			m.ExtractArtifactsSucceeded()

			Expect(buf).To(Say("\nExtracting artifacts...succeeded.\n"))
		})
	})

	Describe("Log out users successfully", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.LogOutUsersStarted()

			Expect(buf).To(Say("\nAttempting to logout any remote users...\n"))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.LogOutUsersSucceeded()

			Expect(buf).To(Say("\nLogged out remote users\n"))
		})

	})

	Describe("Execute setup script messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExecuteSetupScriptStarted()

			Expect(buf).To(Say("\nExecuting setup script 1 of 2...\n"))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExecuteSetupScriptSucceeded()

			Expect(buf).To(Say("\nFinished executing setup script 1 of 2.\n"))
		})

	})

	Describe("Wait for the reboot to have finished", func() {
		It("writes the rebooting message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.WinRMDisconnectedForReboot()

			Expect(buf).To(Say("WinRM has been disconnected so the VM can reboot.\n"))

		})

		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.RebootHasStarted()

			Expect(buf).To(Say("\nThe reboot has started...\n"))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.RebootHasFinished()

			Expect(buf).To(Say("\nThe reboot has finished.\n"))
		})
	})

	Describe("Execute post-reboot script messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExecutePostRebootScriptStarted()

			Expect(buf).To(Say("\nExecuting setup script 2 of 2...\n"))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ExecutePostRebootScriptSucceeded()

			Expect(buf).To(Say("\nFinished executing setup script 2 of 2.\n"))
		})

		It("writes the warning message to the writer", func() {
			m := construct.NewMessenger(buf)

			warning := "winrm was sad"

			m.ExecutePostRebootWarning(warning)

			expectedMessage := "\n" + warning + "\n"
			Expect(buf).To(Say(expectedMessage))
		})

	})

	Describe("Upload file messages", func() {
		It("writes the started message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.UploadFileStarted("some artifact")

			Expect(buf).To(Say("\tUploading some artifact to target VM..."))
		})

		It("writes the succeeded message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.UploadFileSucceeded()

			Expect(buf).To(Say("succeeded.\n"))
		})

		It("writes both messages on one line", func() {
			m := construct.NewMessenger(buf)
			m.UploadFileStarted("some third artifact")
			m.UploadFileSucceeded()

			Expect(buf).To(Say("Uploading some third artifact to target VM...succeed."))
		})
	})

	Describe("validate OS", func() {
		var matchingVersionWarning = "Ensure the version of the stemcell you're trying to build matches the corresponding base ISO you're using.\n" +
			"For example: If you're building 2019.x, then you should be using 'Windows Server 2019' only"
		It("writes the OS version file creation failed message to the writer", func() {
			errorMessage := "some error message"
			m := construct.NewMessenger(buf)
			m.OSVersionFileCreationFailed(errorMessage)
			Expect(buf).To(Say(fmt.Sprintf("Warning: OS Version file creation failed:\n%s\n%s", matchingVersionWarning, errorMessage)))
		})

		It("writes the exit code retrieval failed message to the writer", func() {
			errorMessage := "some error message"
			m := construct.NewMessenger(buf)
			m.ExitCodeRetrievalFailed(errorMessage)
			Expect(buf).To(Say(fmt.Sprintf("Warning: Failed to retrieve exit code for process to create OS Version file:\n%s\n%s", matchingVersionWarning, errorMessage)))
		})

		It("writes the download file failed message to the writer", func() {
			errorMessage := "some error message"
			m := construct.NewMessenger(buf)
			m.DownloadFileFailed(errorMessage)
			Expect(buf).To(Say(fmt.Sprintf("Warning: Failed to download OS Version file:\n%s\n%s", matchingVersionWarning, errorMessage)))
		})
	})

	Describe("Power state messages", func() {
		It("writes still running message with timestamp", func() {
			m := construct.NewMessenger(buf)
			m.WaitingForShutdown()
			// to match timestamp format 2006-01-02T15:04:05.99999-07:00
			//        should also match 2006-01-02T15:04:05.1+07:00
			dateTimeRegex := "\\d{4}\\-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d*(\\-|\\+)\\d{2}:\\d{2}"

			messageString := "Still preparing VM...\n"
			logLineRegex := fmt.Sprintf("%s\\s*%s", dateTimeRegex, messageString)

			Expect(buf).To(Say(logLineRegex))
		})

		It("writes the shutdown message to the writer", func() {
			m := construct.NewMessenger(buf)
			m.ShutdownCompleted()

			Expect(buf).To(Say("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n"))
		})

	})

})
