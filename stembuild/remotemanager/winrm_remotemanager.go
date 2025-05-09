package remotemanager

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"os"
	"time"

	"github.com/masterzen/winrm"
	"github.com/packer-community/winrmcp/winrmcp"
)

const WinRmPort = 5985
const WinRmTimeout = 120 * time.Second

type WinRM struct {
	host          string
	username      string
	password      string
	clientFactory WinRMClientFactoryI
}

//counterfeiter:generate . WinRMClient
type WinRMClient interface {
	Run(command string, stdout io.Writer, stderr io.Writer) (int, error)
	CreateShell() (*winrm.Shell, error)
}

//counterfeiter:generate . WinRMClientFactoryI
type WinRMClientFactoryI interface {
	Build(timeout time.Duration) (WinRMClient, error)
}

func NewWinRM(host string, username string, password string, clientFactory WinRMClientFactoryI) RemoteManager {
	return &WinRM{host, username, password, clientFactory}
}

func (w *WinRM) CanReachVM() error {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", w.host, WinRmPort), time.Second*60)
	if err != nil {
		return fmt.Errorf("host %s is unreachable; lease ensure WinRM is enabled and the IP is correct: %w", w.host, err)
	}

	err = conn.Close()
	if err != nil {
		return fmt.Errorf("could not close connection to host %s: %w", w.host, err)
	}

	return nil
}

func (w *WinRM) CanLoginVM() error {
	winrmClient, err := w.clientFactory.Build(WinRmTimeout)

	if err != nil {
		return fmt.Errorf("failed to create winrm client: %w", err)
	}

	s, err := winrmClient.CreateShell()
	if err != nil {
		return fmt.Errorf("failed to create winrm shell: %w", err)
	}

	err = s.Close()
	if err != nil {
		return fmt.Errorf("failed to close winrm shell: %w", err)
	}

	return nil
}

func (w *WinRM) UploadArtifact(sourceFilePath, destinationFilePath string) error {
	client, err := winrmcp.New(w.host, &winrmcp.Config{
		Auth:                  winrmcp.Auth{User: w.username, Password: w.password},
		Https:                 false,
		Insecure:              true,
		ConnectTimeout:        WinRmTimeout,
		OperationTimeout:      WinRmTimeout,
		MaxOperationsPerShell: 15,
		AllowTimeout:          true,
	})

	if err != nil {
		return err
	}

	// We override Stderr because WinRM Copy output a lot of XML status messages to StdErr
	// even though they are not errors. In addition, these status messages are difficult to read
	// and add little customer value. WinRM does not have an output override for Copy yet
	reader, tmpStdOut, _ := os.Pipe() //nolint:errcheck
	oldStdErr := os.Stderr
	os.Stderr = tmpStdOut

	defer func() {
		os.Stderr = oldStdErr
		tmpStdOut.Close() //nolint:errcheck
		reader.Close()    //nolint:errcheck
	}()

	return client.Copy(sourceFilePath, destinationFilePath)
}

func (w *WinRM) ExtractArchive(source, destination string) error {
	command := fmt.Sprintf("powershell.exe Expand-Archive %s %s -Force", source, destination)
	_, err := w.ExecuteCommand(command)
	return err
}

func (w *WinRM) ExecuteCommandWithTimeout(command string, timeout time.Duration) (int, error) {
	client, err := w.clientFactory.Build(timeout)
	if err != nil {
		return -1, err
	}
	errBuffer := new(bytes.Buffer)
	exitCode, err := client.Run(command, os.Stdout, io.MultiWriter(errBuffer, os.Stderr))
	if err == nil && exitCode != 0 {
		err = fmt.Errorf("%s: %s", PowershellExecutionErrorMessage, errBuffer.String())
	}
	return exitCode, err
}

func (w *WinRM) ExecuteCommand(command string) (int, error) {
	exitCode, err := w.ExecuteCommandWithTimeout(command, WinRmTimeout)
	if err != nil {
		return exitCode, fmt.Errorf("error executing '%s': %w", command, err)
	}

	return exitCode, nil
}
