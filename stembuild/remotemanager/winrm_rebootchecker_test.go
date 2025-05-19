package remotemanager_test

import (
	_ "reflect"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/pkg/errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller/pollerfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"
)

const expectedTryCheckRebootCommand = "shutdown /r /f /t 60 /c \"stembuild reboot test\""

const expectedAbortRebootCommand = "shutdown /a"

var _ = Describe("WinRM RebootChecker", func() {

	var (
		fakeRemoteManager *remotemanagerfakes.FakeRemoteManager
		fakePoller        *pollerfakes.FakePollerI
		rc                *remotemanager.RebootChecker
	)

	BeforeEach(func() {
		fakeRemoteManager = &remotemanagerfakes.FakeRemoteManager{}
		fakePoller = &pollerfakes.FakePollerI{}

		rc = remotemanager.NewRebootChecker(fakeRemoteManager)
	})
	Describe("WaitForRebootFinished", func() {
		It("calls the hasFinished func using the Poller", func() {
			numberOfPollCalls := 8
			fakePoller.PollStub = func(duration time.Duration, pollFunc func() (bool, error)) error {
				for call := 0; call < numberOfPollCalls; call++ {
					pollFunc() //nolint:errcheck
				}
				return nil
			}

			rc := &remotemanagerfakes.FakeRebootCheckerI{}
			rc.RebootHasFinishedReturns(false, nil)
			waiter := remotemanager.NewRebootWaiter(fakePoller, rc)

			waiter.WaitForRebootFinished() //nolint:errcheck

			Expect(fakePoller.PollCallCount()).To(Equal(1))
			Expect(rc.RebootHasFinishedCallCount()).To(Equal(numberOfPollCalls))
		})

		It("returns nil if a reboot has finished successfully", func() {
			fakePoller.PollStub = func(duration time.Duration, pollFunc func() (bool, error)) error {
				pollFunc() //nolint:errcheck
				return nil
			}

			rc := &remotemanagerfakes.FakeRebootCheckerI{}
			rc.RebootHasFinishedReturns(false, nil)
			waiter := remotemanager.NewRebootWaiter(fakePoller, rc)

			err := waiter.WaitForRebootFinished()
			Expect(err).ToNot(HaveOccurred())
		})

		It("returns error if a reboot cannot finish successfully", func() {
			errorMessage := "unable to abort reboot."
			fakePoller.PollReturns(errors.New(errorMessage))

			waiter := remotemanager.NewRebootWaiter(fakePoller, rc)

			err := waiter.WaitForRebootFinished()
			Expect(err.Error()).To(ContainSubstring(errorMessage))
		})
	})

	Describe("RebootHasFinished", func() {
		It("returns false when reboot is in progress", func() {
			someNonzeroExitCode := 1
			fakeRemoteManager.ExecuteCommandReturns(someNonzeroExitCode, nil)

			hasFinished, err := rc.RebootHasFinished()

			Expect(err).NotTo(HaveOccurred())
			Expect(hasFinished).To(BeFalse())
		})

		It("returns false when it could not issue test-reboot command", func() {
			fakeRemoteManager.ExecuteCommandReturns(0, errors.New(""))

			hasFinished, err := rc.RebootHasFinished()

			Expect(hasFinished).To(BeFalse())
			Expect(err).ToNot(HaveOccurred())
		})

		Context("after a reboot has been successfully scheduled", func() {

			BeforeEach(func() {
				fakeRemoteManager.ExecuteCommandReturnsOnCall(0, 0, nil)
			})

			It("aborts reboot when test-reboot succeeds", func() {
				_, err := rc.RebootHasFinished()

				Expect(err).NotTo(HaveOccurred())
				Expect(fakeRemoteManager.ExecuteCommandArgsForCall(1)).
					To(Equal(expectedAbortRebootCommand))
			})

			It("returns an error when abort command could not be issued", func() {
				ErrorExitCode := 0
				fakeRemoteManager.ExecuteCommandReturnsOnCall(1, ErrorExitCode, errors.New("unable to issue abort command"))
				fakeRemoteManager.ExecuteCommandReturnsOnCall(2, ErrorExitCode, errors.New("unable to issue abort command"))
				fakeRemoteManager.ExecuteCommandReturnsOnCall(3, ErrorExitCode, errors.New("unable to issue abort command"))
				fakeRemoteManager.ExecuteCommandReturnsOnCall(4, ErrorExitCode, errors.New("unable to issue abort command"))
				fakeRemoteManager.ExecuteCommandReturnsOnCall(5, ErrorExitCode, errors.New("unable to issue abort command"))

				hasFinished, err := rc.RebootHasFinished()

				Expect(fakeRemoteManager.ExecuteCommandCallCount()).To(Equal(6))

				Expect(hasFinished).To(BeFalse())
				Expect(err).To(MatchError(ContainSubstring("unable to issue abort command")))
			})

			It("returns an error when abort command failed", func() {
				nonZeroExitCode := 1
				fakeRemoteManager.ExecuteCommandReturnsOnCall(1, nonZeroExitCode, nil)

				hasFinished, err := rc.RebootHasFinished()

				Expect(hasFinished).To(BeFalse())
				Expect(err).To(HaveOccurred())
			})

			It("returns true when reboot has finished and when abort succeeds", func() {
				fakeRemoteManager.ExecuteCommandReturnsOnCall(1, 0, nil)

				hasFinished, err := rc.RebootHasFinished()

				Expect(err).NotTo(HaveOccurred())
				Expect(hasFinished).To(Equal(true))
				Expect(fakeRemoteManager.ExecuteCommandCallCount()).
					To(BeNumerically(">=", 1))
				Expect(fakeRemoteManager.ExecuteCommandArgsForCall(0)).
					To(Equal(expectedTryCheckRebootCommand))
			})
		})
	})
})
