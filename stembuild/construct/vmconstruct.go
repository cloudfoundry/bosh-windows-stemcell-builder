package construct

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . VersionGetter
type VersionGetter interface {
	GetVersion() string
}

type VMConstruct struct {
	ctx                   context.Context
	remoteManager         remotemanager.RemoteManager
	Client                IaasClient
	guestManager          GuestManager
	vmInventoryPath       string
	vmUsername            string
	vmPassword            string
	winRMEnabler          WinRMEnabler
	vmConnectionValidator VMConnectionValidator
	messenger             messenger.Messenger
	poller                poller.PollerI
	versionGetter         VersionGetter
	rebootWaiter          RebootWaiterI
	scriptExecutor        ScriptExecutorI
	RebootWaitTime        time.Duration
	SetupFlags            []string
}

const provisionDir = "C:\\provision\\"
const stemcellAutomationName = "StemcellAutomation.zip"
const stemcellAutomationDest = provisionDir + stemcellAutomationName
const lgpoDest = provisionDir + "LGPO.zip"
const stemcellAutomationSetupScript = provisionDir + "Setup.ps1"
const stemcellAutomationPostRebootScript = provisionDir + "PostReboot.ps1"
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"
const boshPsModules = "bosh-psmodules.zip"
const winRMPsScript = "BOSH.WinRM.psm1"

func NewVMConstruct(
	ctx context.Context,
	remoteManager remotemanager.RemoteManager,
	vmUsername,
	vmPassword,
	vmInventoryPath string,
	client IaasClient,
	guestManager GuestManager,
	winRMEnabler WinRMEnabler,
	vmConnectionValidator VMConnectionValidator,
	messenger messenger.Messenger,
	poller poller.PollerI,
	versionGetter VersionGetter,
	rebootWaiter RebootWaiterI,
	scriptExecutor ScriptExecutorI,
	setupFlags []string,
) *VMConstruct {

	return &VMConstruct{
		ctx:                   ctx,
		remoteManager:         remoteManager,
		Client:                client,
		guestManager:          guestManager,
		vmInventoryPath:       vmInventoryPath,
		vmUsername:            vmUsername,
		vmPassword:            vmPassword,
		winRMEnabler:          winRMEnabler,
		vmConnectionValidator: vmConnectionValidator,
		messenger:             messenger,
		poller:                poller,
		versionGetter:         versionGetter,
		rebootWaiter:          rebootWaiter,
		scriptExecutor:        scriptExecutor,
		RebootWaitTime:        time.Second * 60,
		SetupFlags:            setupFlags,
	}
}

//counterfeiter:generate . ScriptExecutorI
type ScriptExecutorI interface {
	ExecuteSetupScript(stembuildVersion string, setupFlags []string) error
	ExecutePostRebootScript(timeout time.Duration) error
}

//counterfeiter:generate . RebootWaiterI
type RebootWaiterI interface {
	WaitForRebootFinished() error
}

//counterfeiter:generate . GuestManager
type GuestManager interface {
	ExitCodeForProgramInGuest(ctx context.Context, pid int64) (int32, error)
	StartProgramInGuest(ctx context.Context, command, args string) (int64, error)
	DownloadFileInGuest(ctx context.Context, path string) (io.Reader, int64, error)
}

//counterfeiter:generate . IaasClient
type IaasClient interface {
	UploadArtifact(vmInventoryPath, artifact, destination, username, password string) error
	MakeDirectory(vmInventoryPath, path, username, password string) error
	Start(vmInventoryPath, username, password, command string, args ...string) (string, error)
	WaitForExit(vmInventoryPath, username, password, pid string) (int, error)
	IsPoweredOff(vmInventoryPath string) (bool, error)
}

//counterfeiter:generate . WinRMEnabler
type WinRMEnabler interface {
	Enable() error
}

//counterfeiter:generate . VMConnectionValidator
type VMConnectionValidator interface {
	Validate() error
}

func (c *VMConstruct) PrepareVM() error {
	stembuildVersion := c.versionGetter.GetVersion()

	err := c.createProvisionDirectory()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("\nTransferring ~20 MB to the Windows VM. Depending on your connection, the transfer may take 15-45 minutes\n")
	err = c.uploadArtifacts()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("\nAll files have been uploaded.\n")

	c.messenger.PrintOut("\nAttempting to enable WinRM on the guest vm...")
	err = c.winRMEnabler.Enable()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("WinRm enabled on the guest VM\n")

	c.messenger.PrintOut("\nValidating connection to vm...")
	err = c.vmConnectionValidator.Validate()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("succeeded.\n")

	c.messenger.PrintOut("\nExtracting artifacts...")
	err = c.extractArchive()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("succeeded.\n")

	c.messenger.PrintOut("\nAttempting to logout any remote users...\n")
	err = c.logOutUsers()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("\nLogged out remote users\n")

	c.messenger.PrintOut("\nExecuting setup script 1 of 2...\n")
	err = c.scriptExecutor.ExecuteSetupScript(stembuildVersion, c.SetupFlags)
	if err != nil {
		return err
	}
	c.messenger.PrintOut("\nFinished executing setup script 1 of 2.\n")
	c.messenger.PrintOut("\nWinRM has been disconnected so the VM can reboot.\n")

	c.messenger.PrintOut("\nThe reboot has started...\n")
	time.Sleep(c.RebootWaitTime)
	err = c.rebootWaiter.WaitForRebootFinished()
	if err != nil {
		return err
	}
	c.messenger.PrintOut("\nThe reboot has finished.\n")

	c.messenger.PrintOut("\nExecuting setup script 2 of 2...\n")
	err = c.scriptExecutor.ExecutePostRebootScript(24 * time.Hour)
	if err != nil {
		if strings.Contains(err.Error(), "winrm connection event") {
			c.messenger.PrintOut(fmt.Sprintf("\n%s\n", err.Error()))
		} else {
			return fmt.Errorf("failure in post-reboot script: %s", err)
		}
	}
	c.messenger.PrintOut("\nFinished executing setup script 2 of 2.\n")

	err = c.isPoweredOff(time.Minute)
	if err != nil {
		return err
	}
	c.messenger.PrintOut("VM has now been shutdown. Run `stembuild package` to finish building the stemcell.\n")

	return nil
}

func (c *VMConstruct) createProvisionDirectory() error {
	c.messenger.PrintOut("\nCreating provision dir on target VM...")
	err := c.Client.MakeDirectory(c.vmInventoryPath, provisionDir, c.vmUsername, c.vmPassword)
	if err != nil {
		return err
	}
	c.messenger.PrintOut("succeeded.\n")
	return nil
}

func (c *VMConstruct) uploadArtifacts() error {
	c.messenger.PrintOut(fmt.Sprintf("\tUploading %s to target VM...", "LGPO"))
	err := c.Client.UploadArtifact(c.vmInventoryPath, "./LGPO.zip", lgpoDest, c.vmUsername, c.vmPassword)
	if err != nil {
		return err
	}
	c.messenger.PrintOut("succeeded.\n")

	c.messenger.PrintOut(fmt.Sprintf("\tUploading %s to target VM...", "stemcell preparation artifacts"))
	err = c.Client.UploadArtifact(c.vmInventoryPath, fmt.Sprintf("./%s", stemcellAutomationName), stemcellAutomationDest, c.vmUsername, c.vmPassword)
	if err != nil {
		return err
	}
	c.messenger.PrintOut("succeeded.\n")

	return nil
}

func (c *VMConstruct) extractArchive() error {
	err := c.remoteManager.ExtractArchive(stemcellAutomationDest, provisionDir)
	return err
}

func (c *VMConstruct) logOutUsers() error {
	failureString := "log out remote user failed with exit code %d: %s"
	rawLogoffCommand := `&{If([string]::IsNullOrEmpty($(Get-WmiObject win32_computersystem).username)) {Write-Host "No users logged in." } Else {Write-Host "Logging out user."; $(Get-WmiObject win32_operatingsystem).Win32Shutdown(0) 1> $null}}`
	logoffCommand := EncodePowershellCommand([]byte(rawLogoffCommand))

	exitCode, err := c.remoteManager.ExecuteCommand("powershell.exe -EncodedCommand " + logoffCommand)

	if err != nil {
		return fmt.Errorf(failureString, exitCode, err)
	}

	return nil
}

func (c *VMConstruct) isPoweredOff(duration time.Duration) error {
	const timeStampFormat = "2006-01-02T15:04:05.999999-07:00"
	err := c.poller.Poll(duration, func() (bool, error) {
		isPoweredOff, err := c.Client.IsPoweredOff(c.vmInventoryPath)

		if err != nil {
			return false, err
		}

		c.messenger.PrintOut(fmt.Sprintf("%s Still preparing VM...\n", time.Now().Format(timeStampFormat)))

		return isPoweredOff, nil
	})
	return err
}

func EncodePowershellCommand(command []byte) string {
	runeCommand := []rune(string(command))
	utf16Command := utf16.Encode(runeCommand)
	byteCommand := &bytes.Buffer{}
	for _, utf16char := range utf16Command {
		b := make([]byte, 2)
		binary.LittleEndian.PutUint16(b, utf16char)
		byteCommand.Write(b)
	}
	return base64.StdEncoding.EncodeToString(byteCommand.Bytes())
}
