package remotemanager

import (
	"time"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . RemoteManager

const PowershellExecutionErrorMessage = "powershell encountered an issue"

type RemoteManager interface {
	UploadArtifact(source, destination string) error
	ExtractArchive(source, destination string) error
	ExecuteCommand(command string) (int, error)
	ExecuteCommandWithTimeout(command string, timeout time.Duration) (int, error)
	CanReachVM() error
	CanLoginVM() error
}
