package messenger

import (
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
