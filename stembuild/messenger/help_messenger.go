package messenger

import (
	"fmt"
	"io"
)

func NewHelpMessenger(output io.Writer) *HelpMessenger {
	return &HelpMessenger{output: output}
}

type HelpMessenger struct {
	output io.Writer
}

func (m *HelpMessenger) UsagePreamble(executable string, version string) {
	write(m.output, fmt.Sprintf("%s version %s, Windows Stemcell Building Tool\n\n", executable, version))
	write(m.output, fmt.Sprintf("Usage: %s <global options> <command> <command flags>\n\n", executable))
}

func (m *HelpMessenger) PrintCommandPreamble() {
	write(m.output, "Commands:\n")
}

func (m *HelpMessenger) PrintCommand(command string, description string) {
	if len(command) < 5 { // This help align the synopses when the commands are of different lengths
		write(m.output, fmt.Sprintf("  %s\t\t%s\n", command, description))
	} else {
		write(m.output, fmt.Sprintf("  %s\t%s\n", command, description))
	}
}

func (m *HelpMessenger) PrintGlobalFlagPreamble() {
	write(m.output, "\nGlobal Options:\n")
}

func (m *HelpMessenger) PrintGlobalFlag(flag string, usage string) {
	if len(flag) > 1 {
		write(m.output, fmt.Sprintf("  -%s\t%s\n", flag, usage))
	} else {
		write(m.output, fmt.Sprintf("  -%s\t\t%s\n", flag, usage))
	}
}
