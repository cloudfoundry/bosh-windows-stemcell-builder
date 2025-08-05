package messenger

import (
	"fmt"
	"io"
)

func NewStembuildMessenger(stdout io.Writer, stderr io.Writer) *StembuildMessenger {
	return &StembuildMessenger{stdout: stdout, stderr: stderr}
}

type StembuildMessenger struct {
	stdout io.Writer
	stderr io.Writer
}

func (m *StembuildMessenger) PrintOut(message string) {
	write(m.stdout, message)
}

func (m *StembuildMessenger) PrintErr(message string) {
	write(m.stderr, message)
}

func (m *StembuildMessenger) VersionInfo(executable string, version string) {
	write(m.stdout, fmt.Sprintf("%s version %s, Windows Stemcell Building Tool\n\n", executable, version))
}

func (m *StembuildMessenger) EnvironmentVariableWarning(envVarName string) {
	write(m.stderr, fmt.Sprintf("Warning: The following environment variable is set and might override flags provided to stembuild: %s\n", envVarName))
}

func (m *StembuildMessenger) StemcellAutomationWarning() {
	write(m.stderr, "Unable to write StemcellAutomation.zip")
}
