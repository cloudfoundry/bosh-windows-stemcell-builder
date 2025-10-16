package construct

import (
	"fmt"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
)

type ScriptExecutor struct {
	remoteManager remotemanager.RemoteManager
}

func NewScriptExecutor(remoteManager remotemanager.RemoteManager) *ScriptExecutor {
	return &ScriptExecutor{
		remoteManager,
	}
}

func (e *ScriptExecutor) ExecuteSetupScript(stembuildVersion string, setupFlags []string) error {
	var automationSetupScriptArgs []string
	automationSetupScriptArgs = append(automationSetupScriptArgs, fmt.Sprintf("-Version %s", stembuildVersion))

	for _, arg := range setupFlags {
		automationSetupScriptArgs = append(automationSetupScriptArgs, fmt.Sprintf("-%s", arg))
	}

	powershellCommand := fmt.Sprintf("powershell.exe %s %s", stemcellAutomationSetupScript, strings.Join(automationSetupScriptArgs, " "))
	_, err := e.remoteManager.ExecuteCommand(powershellCommand)
	return err
}

func (e *ScriptExecutor) ExecutePostRebootScript(timeout time.Duration) error {
	_, err := e.remoteManager.ExecuteCommandWithTimeout("powershell.exe "+stemcellAutomationPostRebootScript, timeout)

	if err != nil && strings.Contains(err.Error(), remotemanager.PowershellExecutionErrorMessage) {
		return err
	}

	if err != nil {
		return fmt.Errorf("winrm connection event: %s", err)
	}

	return nil

}
