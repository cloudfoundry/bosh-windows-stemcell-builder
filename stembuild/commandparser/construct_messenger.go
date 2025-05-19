package commandparser

import (
	"fmt"
	"io"
)

type ConstructCmdMessenger struct {
	OutputChannel io.Writer
}

func (m *ConstructCmdMessenger) printMessage(message string) {
	fmt.Fprintln(m.OutputChannel, message) //nolint:errcheck
}

func (m *ConstructCmdMessenger) ArgumentsNotProvided() {
	m.printMessage("Not all required parameters were provided. See stembuild --help for more details")
}

func (m *ConstructCmdMessenger) LGPONotFound() {
	m.printMessage("Could not find LGPO.zip in the current directory")
}

func (m *ConstructCmdMessenger) CannotConnectToVM(err error) {
	m.printMessage(fmt.Sprintf("Cannot connect to VM: %s", err))
}

func (m *ConstructCmdMessenger) CannotPrepareVM(err error) {
	m.printMessage(fmt.Sprintf("Could not prepare VM: %s", err))
}
