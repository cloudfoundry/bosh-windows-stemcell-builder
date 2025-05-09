package commandparser

import (
	"fmt"
	"io"
)

type PackageMessenger struct {
	Output io.Writer
}

func (m *PackageMessenger) InvalidOutputConfig(e error) {
	fmt.Fprintln(m.Output, e) //nolint:errcheck
}

func (m *PackageMessenger) CannotCreatePackager(e error) {
	fmt.Fprintln(m.Output, e) //nolint:errcheck
}

func (m *PackageMessenger) DoesNotHaveEnoughSpace(e error) {
	fmt.Fprintln(m.Output, e) //nolint:errcheck
}

func (m *PackageMessenger) SourceParametersAreInvalid(e error) {
	fmt.Fprintln(m.Output, e) //nolint:errcheck
}

func (m *PackageMessenger) PackageFailed(e error) {
	fmt.Fprintln(m.Output, e)                                                              //nolint:errcheck
	fmt.Fprintln(m.Output, "Please provide the error logs to bosh-windows-eng@pivotal.io") //nolint:errcheck
}
