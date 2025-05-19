package guest_manager_test

import (
	"context"
	"errors"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/vmware/govmomi/vim25/types"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/guest_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/guest_manager/guest_managerfakes"
)

var _ = Describe("GuestManager", func() {
	var (
		auth         types.NamePasswordAuthentication
		ctx          context.Context
		procManager  guest_managerfakes.FakeProcManager
		fileManager  guest_managerfakes.FakeFileManager
		client       guest_managerfakes.FakeDownloadClient
		guestManager *guest_manager.GuestManager
	)

	BeforeEach(func() {
		ctx = context.TODO()
		auth = types.NamePasswordAuthentication{}
		procManager = guest_managerfakes.FakeProcManager{}
		fileManager = guest_managerfakes.FakeFileManager{}
		client = guest_managerfakes.FakeDownloadClient{}
		guestManager = guest_manager.NewGuestManager(auth, &procManager, &fileManager, &client)
	})

	Describe("StartProgramInGuest", func() {
		It("runs the command on the guest", func() {
			expectedPid := int64(600)
			procManager.StartProgramReturns(expectedPid, nil)

			pid, err := guestManager.StartProgramInGuest(ctx, "mkdir", "C:\\dummy")
			Expect(err).NotTo(HaveOccurred())
			Expect(pid).To(Equal(expectedPid))
		})

		It("returns an error if StartProgram does", func() {
			procManager.StartProgramReturns(int64(0), errors.New("You aint nothin but a hound dog"))

			_, err := guestManager.StartProgramInGuest(ctx, "mkdir", "C:\\dummy")
			Expect(err).To(MatchError("vcenter_client - could not run process: mkdir C:\\dummy on guest os, error: You aint nothin but a hound dog"))
		})
	})

	Describe("ExitCodeForProgramInGuest", func() {
		It("obtains the exit code when the given program, being run on the guest os, exits", func() {
			expectedTime := time.Now()
			expectedExitCode := int32(0)
			processInfo := types.GuestProcessInfo{
				ExitCode: expectedExitCode,
				EndTime:  &expectedTime,
			}

			procManager.ListProcessesReturns([]types.GuestProcessInfo{processInfo}, nil)

			exitCode, err := guestManager.ExitCodeForProgramInGuest(ctx, 1000)
			Expect(err).NotTo(HaveOccurred())
			Expect(exitCode).To(Equal(expectedExitCode))
		})

		It("returns an error if ListProcesses does", func() {
			procManager.ListProcessesReturns(nil, errors.New("yo"))

			_, err := guestManager.ExitCodeForProgramInGuest(ctx, 1000)
			Expect(err).To(MatchError("vcenter_client - could not observe program exiting: yo"))
		})

		It("returns an error if ListProcesses does not find pid", func() {
			procManager.ListProcessesReturns([]types.GuestProcessInfo{}, nil)

			_, err := guestManager.ExitCodeForProgramInGuest(ctx, 1000)
			Expect(err).To(MatchError("vcenter_client - could not observe program exiting"))
		})
	})

	Describe("DownloadFileInGuest", func() {
		It("returns an error if  qInitiateFileTransferFromGuest fails", func() {
			fileManager.InitiateFileTransferFromGuestReturns(nil, errors.New("couldn't initiate file transfer :("))

			_, _, err := guestManager.DownloadFileInGuest(context.TODO(), "MYPATH")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - unable to download file: couldn't initiate file transfer :("))
		})

		It("returns an error if TransferURL fails", func() {
			fileManager.InitiateFileTransferFromGuestReturns(&types.FileTransferInformation{Url: "my.dude.edu"}, nil)
			fileManager.TransferURLReturns(nil, errors.New("couldn't initiate file transfer :("))

			_, _, err := guestManager.DownloadFileInGuest(context.TODO(), "MYPATH")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - unable to download file: couldn't initiate file transfer :("))
		})

		It("returns an error if Download fails", func() {
			fileManager.InitiateFileTransferFromGuestReturns(&types.FileTransferInformation{Url: "my.dude.edu"}, nil)
			client.DownloadReturns(nil, 0, errors.New("couldn't initiate file transfer :("))

			_, _, err := guestManager.DownloadFileInGuest(context.TODO(), "MYPATH")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("vcenter_client - unable to download file: couldn't initiate file transfer :("))
		})

		It("successfully downloads file", func() {
			fileManager.InitiateFileTransferFromGuestReturns(&types.FileTransferInformation{Url: "my.dude.edu"}, nil)

			_, _, err := guestManager.DownloadFileInGuest(context.TODO(), "C://PATH")
			Expect(err).ToNot(HaveOccurred())
			Expect(fileManager.InitiateFileTransferFromGuestCallCount()).To(Equal(1))
			Expect(fileManager.TransferURLCallCount()).To(Equal(1))
			Expect(client.DownloadCallCount()).To(Equal(1))
		})
	})
})
