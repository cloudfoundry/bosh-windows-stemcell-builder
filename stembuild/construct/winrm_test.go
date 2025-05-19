package construct_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/assets"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/constructfakes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("WinRMManager", func() {
	var (
		winrmManager      *construct.WinRMManager
		fakeGuestManager  *constructfakes.FakeGuestManager
		fakeZipUnarchiver *constructfakes.FakeZipUnarchiver
		saByteData        []byte
	)

	BeforeEach(func() {
		fakeGuestManager = &constructfakes.FakeGuestManager{}
		fakeZipUnarchiver = &constructfakes.FakeZipUnarchiver{}

		saByteData = assets.StemcellAutomation

		winrmManager = &construct.WinRMManager{
			GuestManager: fakeGuestManager,
			Unarchiver:   fakeZipUnarchiver,
		}
	})

	Describe("Enable", func() {
		It("returns success when it enables WinRM on the guest VM", func() {
			expectedPid := int64(65535)
			fakeGuestManager.StartProgramInGuestReturns(expectedPid, nil)

			fakeZipUnarchiver.UnzipReturnsOnCall(0, []byte("bosh-psmodules.zip extracted byte array"), nil)
			fakeZipUnarchiver.UnzipReturnsOnCall(1, []byte("BOSH.WinRM.psm1 extracted byte array"), nil)

			err := winrmManager.Enable()
			Expect(err).ToNot(HaveOccurred())

			Expect(fakeZipUnarchiver.UnzipCallCount()).To(Equal(2))
			Expect(fakeGuestManager.StartProgramInGuestCallCount()).To(Equal(1))
			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(1))

			archive, fileName := fakeZipUnarchiver.UnzipArgsForCall(0)
			Expect(fileName).To(Equal("bosh-psmodules.zip"))
			Expect(archive).To(Equal(saByteData))

			archive, fileName = fakeZipUnarchiver.UnzipArgsForCall(1)
			Expect(fileName).To(Equal("BOSH.WinRM.psm1"))
			Expect(archive).To(Equal([]byte("bosh-psmodules.zip extracted byte array")))

			_, command, args := fakeGuestManager.StartProgramInGuestArgsForCall(0)
			// Though the directory uses v1.0, this is also valid for Powershell 5 that we require
			Expect(command).To(Equal("C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"))
			// The encoded string was created by running the following in terminal `printf "BOSH.WinRM.psm1 extracted byte array\nEnable-WinRM" | iconv -t UTF-16LE | openssl base64 | tr -d '\n'`
			Expect(args).To(Equal("-EncodedCommand QgBPAFMASAAuAFcAaQBuAFIATQAuAHAAcwBtADEAIABlAHgAdAByAGEAYwB0AGUAZAAgAGIAeQB0AGUAIABhAHIAcgBhAHkACgBFAG4AYQBiAGwAZQAtAFcAaQBuAFIATQAKAA=="))

			_, pid := fakeGuestManager.ExitCodeForProgramInGuestArgsForCall(0)
			Expect(pid).To(Equal(expectedPid))
		})

		It("returns a failure when fails to find BOSH.WinRM.psm1 in bosh-psmodules.zip", func() {
			execError := errors.New("failed to find BOSH.WinRM.psm1")
			fakeZipUnarchiver.UnzipReturnsOnCall(0, []byte("bosh-psmodules.zip extracted byte array"), nil)
			fakeZipUnarchiver.UnzipReturnsOnCall(1, nil, execError)

			err := winrmManager.Enable()
			Expect(err).To(MatchError("failed to enable WinRM: failed to find BOSH.WinRM.psm1"))

			Expect(fakeGuestManager.StartProgramInGuestCallCount()).To(Equal(0))
			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(0))
		})

		It("returns a failure when it fails to find bosh-psmodules.zip in the archive artifact", func() {
			execError := errors.New("failed to find bosh-psmodules.zip")
			fakeZipUnarchiver.UnzipReturnsOnCall(0, nil, execError)

			err := winrmManager.Enable()
			Expect(err).To(MatchError("failed to enable WinRM: failed to find bosh-psmodules.zip"))
			Expect(fakeZipUnarchiver.UnzipCallCount()).To(Equal(1))

			Expect(fakeGuestManager.StartProgramInGuestCallCount()).To(Equal(0))
			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(0))

		})

		It("returns failure when starting a program in guest returns an error", func() {
			startError := errors.New("failed to start program in guest")
			fakeGuestManager.StartProgramInGuestReturns(0, startError)

			err := winrmManager.Enable()
			Expect(err).To(MatchError("failed to enable WinRM: failed to start program in guest"))

			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(0))
		})

		It("returns failure when WinRM process on guest VM exited with non zero exit code", func() {
			expectedPid := int64(1456)
			fakeGuestManager.StartProgramInGuestReturns(expectedPid, nil)
			fakeGuestManager.ExitCodeForProgramInGuestReturns(int32(120), nil)

			err := winrmManager.Enable()
			Expect(err).To(MatchError("failed to enable WinRM: WinRM process on guest VM exited with code 120"))

			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(1))

			_, actualPid := fakeGuestManager.ExitCodeForProgramInGuestArgsForCall(0)
			Expect(actualPid).To(Equal(expectedPid))
		})

		It("returns failure when it fails to poll for enable WinRM process on guest vm", func() {
			expectedPid := int64(1456)
			fakeGuestManager.StartProgramInGuestReturns(expectedPid, nil)
			execError := errors.New("failed to find PID")
			fakeGuestManager.ExitCodeForProgramInGuestReturns(int32(1), execError)

			err := winrmManager.Enable()
			Expect(err).To(MatchError("failed to enable WinRM: failed to find PID"))

			Expect(fakeGuestManager.ExitCodeForProgramInGuestCallCount()).To(Equal(1))
			_, pid := fakeGuestManager.ExitCodeForProgramInGuestArgsForCall(0)

			Expect(pid).To(Equal(expectedPid))
		})
	})
})
