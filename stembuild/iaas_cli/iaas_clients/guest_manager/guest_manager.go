package guest_manager

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"time"

	"github.com/vmware/govmomi/vim25"
	"github.com/vmware/govmomi/vim25/soap"
	"github.com/vmware/govmomi/vim25/types"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . ProcManager
type ProcManager interface {
	StartProgram(ctx context.Context, auth types.BaseGuestAuthentication, spec types.BaseGuestProgramSpec) (int64, error)
	ListProcesses(ctx context.Context, auth types.BaseGuestAuthentication, pids []int64) ([]types.GuestProcessInfo, error)
	Client() *vim25.Client
}

//counterfeiter:generate . FileManager
type FileManager interface {
	InitiateFileTransferFromGuest(ctx context.Context, auth types.BaseGuestAuthentication, guestFilePath string) (*types.FileTransferInformation, error)
	TransferURL(ctx context.Context, u string) (*url.URL, error)
}

//counterfeiter:generate . DownloadClient
type DownloadClient interface {
	Download(ctx context.Context, u *url.URL, param *soap.Download) (io.ReadCloser, int64, error)
}

type GuestManager struct {
	auth           types.NamePasswordAuthentication
	processManager ProcManager
	fileManager    FileManager
	client         DownloadClient
}

func NewGuestManager(auth types.NamePasswordAuthentication, processManager ProcManager, fileManager FileManager, client DownloadClient) *GuestManager {
	return &GuestManager{auth, processManager, fileManager, client}
}

func (g *GuestManager) StartProgramInGuest(ctx context.Context, command, args string) (int64, error) {
	spec := types.GuestProgramSpec{
		ProgramPath: command,
		Arguments:   args,
	}

	pid, err := g.processManager.StartProgram(ctx, &g.auth, &spec)
	if err != nil {
		return -1, fmt.Errorf("vcenter_client - could not run process: %s on guest os, error: %s",
			fmt.Sprintf("%s %s", command, args), err.Error())
	}

	return pid, nil
}

func (g *GuestManager) ExitCodeForProgramInGuest(ctx context.Context, pid int64) (int32, error) {
	for {
		procs, err := g.processManager.ListProcesses(ctx, &g.auth, []int64{pid})
		if err != nil {
			return -1, fmt.Errorf("vcenter_client - could not observe program exiting: %s", err.Error())
		}

		if len(procs) != 1 {
			return -1, fmt.Errorf("vcenter_client - could not observe program exiting")
		}

		if procs[0].EndTime == nil {
			<-time.After(time.Millisecond * 250)
			continue
		}

		return procs[0].ExitCode, nil
	}
}

func (g *GuestManager) DownloadFileInGuest(ctx context.Context, path string) (io.Reader, int64, error) {
	info, err := g.fileManager.InitiateFileTransferFromGuest(ctx, &g.auth, path)
	if err != nil {
		return nil, 0, fmt.Errorf("vcenter_client - unable to download file: %s", err.Error())
	}

	u, err := g.fileManager.TransferURL(ctx, info.Url)
	if err != nil {
		return nil, 0, fmt.Errorf("vcenter_client - unable to download file: %s", err.Error())
	}

	p := soap.DefaultDownload

	f, n, err := g.client.Download(ctx, u, &p)
	if err != nil {
		return nil, n, fmt.Errorf("vcenter_client - unable to download file: %s", err.Error())
	}

	return f, n, nil
}
