package iaas_clients

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"regexp"
	"strings"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"
)

type VcenterClient struct {
	Url           string
	credentialUrl string
	redactedUrl   string
	caCertFile    string
	Runner        iaas_cli.CliRunner
}

func NewVcenterClient(username string, password string, u string, caCertFile string, runner iaas_cli.CliRunner) *VcenterClient {
	encodedUser := url.QueryEscape(username)
	encodedPassword := url.QueryEscape(password)
	urlWithCredentials := fmt.Sprintf("%s:%s@%s", encodedUser, encodedPassword, u)
	urlWithRedactedPassword := fmt.Sprintf("%s:REDACTED@%s", encodedUser, u)

	return &VcenterClient{
		Url:           u,
		credentialUrl: urlWithCredentials,
		redactedUrl:   urlWithRedactedPassword,
		caCertFile:    caCertFile,
		Runner:        runner,
	}
}

func (c *VcenterClient) ValidateUrl() error {
	args := []string{"about", "-u", c.Url}
	errMsg := "unable to validate url"
	if c.caCertFile != "" {
		args = append(args, fmt.Sprintf("-tls-ca-certs=%s", c.caCertFile))
		errMsg = "invalid ca certs or url"
	}

	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - %s: %s", errMsg, c.Url)
	}

	return nil
}

func (c *VcenterClient) ValidateCredentials() error {
	args := c.buildGovcCommand("about")
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - invalid credentials for: %s", c.redactedUrl)
	}

	return nil
}

func (c *VcenterClient) FindVM(vmInventoryPath string) error {
	args := c.buildGovcCommand("find", "-maxdepth=0", vmInventoryPath)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - unable to find VM: %s. Ensure your inventory path is formatted properly and includes \"vm\" in its path, example: /my-datacenter/vm/my-folder/my-vm-name", vmInventoryPath)
	}

	return nil
}

func (c *VcenterClient) ListDevices(vmInventoryPath string) ([]string, error) {
	args := c.buildGovcCommand("device.ls", "-vm", vmInventoryPath)
	o, exitCode, err := c.Runner.RunWithOutput(args)

	if exitCode != 0 {
		return []string{}, fmt.Errorf("vcenter_client - failed to list devices in vCenter, govc exit code %d", exitCode)
	}

	if err != nil {
		return []string{}, fmt.Errorf("vcenter_client - failed to parse list of devices. Err: %s", err)
	}

	entries := strings.Split(o, "\n")
	devices := []string{}
	r := regexp.MustCompile(`\S+`)
	for _, entry := range entries {
		if entry != "" {
			devices = append(devices, r.FindString(entry))
		}
	}

	return devices, nil
}
func (c *VcenterClient) RemoveDevice(vmInventoryPath string, deviceName string) error {
	args := c.buildGovcCommand("device.remove", "-vm", vmInventoryPath, deviceName)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - %s could not be removed", deviceName)
	}

	return nil
}

func (c *VcenterClient) EjectCDRom(vmInventoryPath string, deviceName string) error {
	args := c.buildGovcCommand("device.cdrom.eject", "-vm", vmInventoryPath, "-device", deviceName)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - %s could not be ejected", deviceName)
	}

	return nil
}

func (c *VcenterClient) ExportVM(vmInventoryPath string, destination string) error {
	_, err := os.Stat(destination)
	if err != nil {
		return fmt.Errorf("vcenter_client - provided destination directory: %s does not exist", destination)
	}
	args := c.buildGovcCommand("export.ovf", "-sha", "1", "-vm", vmInventoryPath, destination)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - %s could not be exported", vmInventoryPath)
	}

	return nil
}

func (c *VcenterClient) UploadArtifact(vmInventoryPath, artifact, destination, username, password string) error {
	vmCredentials := fmt.Sprintf("%s:%s", username, password)
	args := c.buildGovcCommand("guest.upload", "-f", "-l", vmCredentials, "-vm", vmInventoryPath, artifact, destination)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - %s could not be uploaded", artifact)
	}

	return nil
}

func (c *VcenterClient) MakeDirectory(vmInventoryPath, path, username, password string) error {
	vmCredentials := fmt.Sprintf("%s:%s", username, password)

	args := c.buildGovcCommand("guest.mkdir", "-l", vmCredentials, "-vm", vmInventoryPath, "-p", path)
	errCode := c.Runner.Run(args)
	if errCode != 0 {
		return fmt.Errorf("vcenter_client - directory `%s` could not be created", path)
	}

	return nil
}

func (c *VcenterClient) Start(vmInventoryPath, username, password, command string, args ...string) (string, error) {
	vmCredentials := fmt.Sprintf("%s:%s", username, password)

	cmdArgs := c.buildGovcCommand(append([]string{"guest.start", "-l", vmCredentials, "-vm", vmInventoryPath, command}, args...)...)
	pid, exitCode, err := c.Runner.RunWithOutput(cmdArgs)
	if err != nil {
		return "", fmt.Errorf("vcenter_client - failed to run '%s': %s", command, err)
	}
	if exitCode != 0 {
		return "", fmt.Errorf("vcenter_client - '%s' returned exit code: %d", command, exitCode)
	}

	return strings.TrimSuffix(pid, "\n"), nil // trim since govc outputs the pid with an '\n' in the output
}

type govcPS struct {
	ProcessInfo []struct {
		Name      string
		Pid       int
		Owner     string
		CmdLine   string
		StartTime string
		EndTime   string
		ExitCode  int
	}
}

func (c *VcenterClient) WaitForExit(vmInventoryPath, username, password, pid string) (int, error) {
	vmCredentials := fmt.Sprintf("%s:%s", username, password)
	args := c.buildGovcCommand("guest.ps", "-l", vmCredentials, "-vm", vmInventoryPath, "-p", pid, "-X", "-json")
	output, exitCode, err := c.Runner.RunWithOutput(args)
	if err != nil {
		return 0, fmt.Errorf("vcenter_client - failed to fetch exit code for PID %s: %s", pid, err)
	}
	if exitCode != 0 {
		return 0, fmt.Errorf("vcenter_client - fetching PID %s returned with exit code: %d", pid, exitCode)
	}

	ps := govcPS{}
	err = json.Unmarshal([]byte(output), &ps)
	if err != nil {
		return 0, fmt.Errorf("vcenter_client - received bad JSON output for PID %s: %s", pid, output)
	}
	if len(ps.ProcessInfo) != 1 {
		return 0, fmt.Errorf("vcenter_client - couldn't get exit code for PID %s", pid)
	}

	return ps.ProcessInfo[0].ExitCode, nil
}

func (c *VcenterClient) buildGovcCommand(args ...string) []string {
	commonArgs := []string{"-u", c.credentialUrl}
	if c.caCertFile != "" {
		commonArgs = append(commonArgs, fmt.Sprintf("-tls-ca-certs=%s", c.caCertFile))
	}
	args = append(args[:1], append(commonArgs, args[1:]...)...)

	return args
}

func (c *VcenterClient) IsPoweredOff(vmInventoryPath string) (bool, error) {
	args := c.buildGovcCommand("vm.info", vmInventoryPath)
	out, exitCode, err := c.Runner.RunWithOutput(args)
	if exitCode != 0 {
		return false, fmt.Errorf("vcenter_client - failed to get vm info, govc exit code: %d", exitCode)
	}

	if err != nil {
		return false, fmt.Errorf("vcenter_client - failed to determine vm power state: %s", err)
	}

	if strings.Contains(out, "poweredOff") {
		return true, nil
	}

	return false, nil
}
