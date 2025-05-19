package commandparser_test

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path"

	"github.com/google/subcommands"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"
)

var _ = Describe("help", func() {
	// Focus of this test is not to test the Flags.Parse functionality as much
	// as to test that the command line flags values are stored in the expected
	// struct variables. This adds a bit of protection when renaming flag parameters.
	Describe("Explain", func() {
		It("shows the correct version", func() {
			version.Version = "1.56"
			buf := bytes.Buffer{}
			fs := flag.NewFlagSet(path.Base(os.Args[0]), flag.ExitOnError)
			commands := make([]subcommands.Command, 0)
			sb := commandparser.NewStembuildHelp(subcommands.DefaultCommander, fs, &commands)

			sb.Explain(&buf)

			expectedString := fmt.Sprintf("%s version %s, Windows Stemcell Building Tool", path.Base(os.Args[0]), version.Version)
			Expect(buf.String()).To(ContainSubstring(expectedString))
		})
	})
})
