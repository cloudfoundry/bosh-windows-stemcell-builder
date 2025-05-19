//go:build darwin
// +build darwin

package ovftool_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/ovftool"
)

var _ = Describe("ovftool darwin", func() {
	Context("homeDirectory", func() {
		It("returns value of HOME environment variable is set", func() {
			envHomedir := "/fake/envHomedir/dir"
			GinkgoT().Setenv("HOME", envHomedir)

			testHome := ovftool.HomeDirectory()
			Expect(testHome).To(Equal(envHomedir))
		})

		It("returns user HOME directory if HOME environment variable is not set", func() {
			GinkgoT().Setenv("HOME", "")

			osHomedirBytes, err := exec.Command("sh", "-c", "cd ~ && pwd").Output()
			Expect(err).NotTo(HaveOccurred())
			osHomedir := string(bytes.TrimSpace(osHomedirBytes))

			testHome := ovftool.HomeDirectory()
			Expect(testHome).To(Equal(osHomedir))
		})
	})

	Context("Ovftool", func() {
		BeforeEach(func() {
			GinkgoT().Setenv("PATH", "")
		})

		It("when ovftool is on the path, its path is returned", func() {
			tmpDir := GinkgoT().TempDir() // automatically cleaned up
			err := os.WriteFile(filepath.Join(tmpDir, "ovftool"), []byte{}, 0700)
			Expect(err).ToNot(HaveOccurred())
			GinkgoT().Setenv("PATH", tmpDir)

			ovfPath, err := ovftool.Ovftool([]string{})
			Expect(err).ToNot(HaveOccurred())
			Expect(ovfPath).To(Equal(filepath.Join(tmpDir, "ovftool")))
		})

		It("fails when given invalid set of install paths", func() {
			tmpDir := GinkgoT().TempDir() // automatically cleaned up

			_, err := ovftool.Ovftool([]string{tmpDir})

			Expect(err).To(HaveOccurred())
		})

		It("fails when given empty set of install paths", func() {
			_, err := ovftool.Ovftool([]string{})
			Expect(err).To(HaveOccurred())
		})

		Context("when ovftool is installed", func() {
			var tmpDir, dummyDir string

			BeforeEach(func() {
				tmpDir = GinkgoT().TempDir()   // automatically cleaned up
				dummyDir = GinkgoT().TempDir() // automatically cleaned up
				err := os.WriteFile(filepath.Join(tmpDir, "ovftool"), []byte{}, 0700)
				Expect(err).ToNot(HaveOccurred())
			})

			It("Returns the path to the ovftool", func() {
				ovfPath, err := ovftool.Ovftool([]string{"notrealdir", dummyDir, tmpDir})

				Expect(err).ToNot(HaveOccurred())
				Expect(ovfPath).To(Equal(filepath.Join(tmpDir, "ovftool")))
			})
		})
	})
})
