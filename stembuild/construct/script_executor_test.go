package construct_test

import (
	"errors"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"
)

var _ = Describe("NewScriptExecutor", func() {
	var (
		fakeRemoteManager *remotemanagerfakes.FakeRemoteManager

		scriptExecutor *construct.ScriptExecutor
	)

	BeforeEach(func() {
		fakeRemoteManager = &remotemanagerfakes.FakeRemoteManager{}

		scriptExecutor = construct.NewScriptExecutor(fakeRemoteManager)
	})

	Describe("ScriptExecutor", func() {
		Describe("ExecuteSetupScript", func() {
			It("executes setup script with correct arguments", func() {
				version := "11.11.11"
				setupFlags := []string{"SomeFlag SomeValue", "OtherFlag OtherValue"}
				expectedCommandInvocation :=
					fmt.Sprintf(
						"powershell.exe %s -Version %s %s",
						`C:\provision\Setup.ps1`,
						version,
						"-SomeFlag SomeValue -OtherFlag OtherValue",
					)

				err := scriptExecutor.ExecuteSetupScript(version, setupFlags)
				Expect(err).NotTo(HaveOccurred())

				executeCommandCallArg := fakeRemoteManager.ExecuteCommandArgsForCall(0)

				Expect(executeCommandCallArg).To(Equal(expectedCommandInvocation))
			})
		})

		Describe("ExecutePostRebootScript", func() {
			var expectedTimeout time.Duration

			BeforeEach(func() {
				expectedTimeout = 24 * time.Hour
			})

			It("executes post-reboot script with correct arguments", func() {
				expectedCommandInvocation :=
					fmt.Sprintf(
						"powershell.exe %s",
						`C:\provision\PostReboot.ps1`,
					)

				err := scriptExecutor.ExecutePostRebootScript(expectedTimeout)
				Expect(err).NotTo(HaveOccurred())

				executeCommandWithTimeoutCallArg, actualTimeout := fakeRemoteManager.ExecuteCommandWithTimeoutArgsForCall(0)

				Expect(executeCommandWithTimeoutCallArg).To(Equal(expectedCommandInvocation))
				Expect(expectedTimeout).To(Equal(actualTimeout))
			})

			Context("when there is an error", func() {
				var commandExecutionErrorCode int
				var commandExecutionErr error

				BeforeEach(func() {
					commandExecutionErrorCode = 999
				})

				Context("when the error is a powershell execution error", func() {
					BeforeEach(func() {
						powershellErrorPrefix := errors.New(remotemanager.PowershellExecutionErrorMessage)
						commandExecutionErr = fmt.Errorf("%s: %s", powershellErrorPrefix, "a command failed to run")

						fakeRemoteManager.ExecuteCommandWithTimeoutReturns(commandExecutionErrorCode, commandExecutionErr)
					})

					It("returns the error", func() {
						err := scriptExecutor.ExecutePostRebootScript(expectedTimeout)

						Expect(err).To(MatchError(commandExecutionErr))
					})
				})

				Context("when the error is a NOT powershell execution error", func() {
					BeforeEach(func() {
						commandExecutionErr = errors.New("fake-non-powershell-execution-error")
					})

					It("wraps a non-powershell execution error", func() {
						fakeRemoteManager.ExecuteCommandWithTimeoutReturns(1, commandExecutionErr)

						err := scriptExecutor.ExecutePostRebootScript(expectedTimeout)

						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(Equal(fmt.Sprintf("winrm connection event: %s", commandExecutionErr.Error())))
					})
				})
			})
		})
	})
})
