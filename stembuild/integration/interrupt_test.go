//go:build !windows
// +build !windows

package integration_test

import (
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Interrupts", func() {
	Describe("catchInterruptSignal", func() {
		// Tried to create test to handle 2 interrupts in a row, but timing of processes makes testing difficult

		It("cleans up on one interrupt", func() {
			var err error
			stembuildExecutable, err = helpers.BuildStembuild("1200.0.0")
			Expect(err).ToNot(HaveOccurred())

			inputVmdk := filepath.Join("..", "test", "data", "expected.vmdk")
			tmpDir := GinkgoT().TempDir() // automatically cleaned up

			session := helpers.Stembuild(stembuildExecutable, "package", "--vmdk", inputVmdk, "--outputDir", tmpDir)
			time.Sleep(1 * time.Second)

			err = session.Command.Process.Signal(os.Interrupt)
			Expect(err).ToNot(HaveOccurred())
			time.Sleep(1 * time.Second)

			stdErr := session.Err.Contents()
			Expect(string(stdErr)).To(ContainSubstring("received ("))
		})
	})
})
