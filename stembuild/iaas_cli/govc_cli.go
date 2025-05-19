package iaas_cli

import (
	"bytes"
	"io"
	"os"

	"github.com/vmware/govmomi/cli"
	_ "github.com/vmware/govmomi/cli/about"
	_ "github.com/vmware/govmomi/cli/device"
	_ "github.com/vmware/govmomi/cli/device/cdrom"
	_ "github.com/vmware/govmomi/cli/export"
	_ "github.com/vmware/govmomi/cli/object"
	_ "github.com/vmware/govmomi/cli/vm"
	_ "github.com/vmware/govmomi/cli/vm/guest"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . CliRunner
type CliRunner interface {
	Run(args []string) int
	RunWithOutput(args []string) (string, int, error)
}

type GovcRunner struct {
}

func (r *GovcRunner) Run(args []string) int {
	return cli.Run(args)
}

func (r *GovcRunner) RunWithOutput(args []string) (string, int, error) {
	old := os.Stdout          // keep backup of the real stdout
	reader, w, _ := os.Pipe() //nolint:errcheck
	os.Stdout = w

	print()

	outC := make(chan string)
	errC := make(chan error)
	// copy the output in a separate goroutine so printing can't block indefinitely
	go func() {
		var buf bytes.Buffer
		_, err := io.Copy(&buf, reader)
		if err != nil {
			errC <- err
		} else {
			outC <- buf.String()
		}
	}()

	exitCode := r.Run(args)

	// back to normal state
	err := w.Close()
	os.Stdout = old // restoring the real stdout
	if err != nil {
		return "", exitCode, err
	}

	select {
	case out := <-outC:
		return out, exitCode, nil
	case err := <-errC:
		return "", exitCode, err
	}
}
