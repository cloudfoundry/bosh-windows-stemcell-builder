//go:build !darwin && !windows
// +build !darwin,!windows

package ovftool_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/ovftool"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ovftool", func() {
	It("when ovftool is on the PATH, its path is returned", func() {
		tmpDir := GinkgoT().TempDir() // automatically cleaned up
		err := os.WriteFile(filepath.Join(tmpDir, "ovftool"), []byte{}, 0700)
		Expect(err).ToNot(HaveOccurred())

		GinkgoT().Setenv("PATH", tmpDir)

		ovfPath, err := ovftool.Ovftool([]string{})
		Expect(err).ToNot(HaveOccurred())
		Expect(ovfPath).To(Equal(filepath.Join(tmpDir, "ovftool")))
	})

	It("fails when ovftool is not installed in the PATH", func() {
		GinkgoT().Setenv("PATH", "/tmp")

		_, err := ovftool.Ovftool([]string{})
		Expect(err).To(HaveOccurred())
	})
})
