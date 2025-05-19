package ovftool_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"golang.org/x/sys/windows/registry"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/ovftool"
)

var _ = Describe("ovftool", func() {
	Context("vmwareInstallPaths", func() {
		It("returns install paths when given valid set of registry key paths", func() {
			keypaths := []string{
				`SOFTWARE\Wow6432Node\VMware, Inc.\VMware Workstation`,
				`SOFTWARE\Wow6432Node\VMware, Inc.\VMware OVF Tool`,
				`SOFTWARE\VMware, Inc.\VMware Workstation`,
				`SOFTWARE\VMware, Inc.\VMware OVF Tool`,
			}

			searchPaths, err := ovftool.VmwareInstallPaths(keypaths)

			Expect(err).ToNot(HaveOccurred())
			Expect(searchPaths).ToNot(BeNil())
		})

		It("fails when given invalid registry key path", func() {
			keypaths := []string{`\SOFTWARE\fake-temp-key`}

			_, err := ovftool.VmwareInstallPaths(keypaths)

			Expect(err).To(HaveOccurred())
		})

		It("fails when given empty set of registry keys paths", func() {
			var keypaths []string

			_, err := ovftool.VmwareInstallPaths(keypaths)

			Expect(err).To(HaveOccurred())
		})

		Context("when given a valid registry keypath that does not have an installPath[64] value", func() {
			var key registry.Key
			var keypaths []string

			BeforeEach(func() {
				var err error
				key, err = registry.OpenKey(registry.CURRENT_USER, `SOFTWARE`, registry.WRITE)
				Expect(err).ToNot(HaveOccurred())
				_, exists, err := registry.CreateKey(key, `fake-temp-key`, registry.WRITE)
				Expect(err).ToNot(HaveOccurred())
				Expect(exists).To(BeFalse())
				keypaths = []string{`\SOFTWARE\fake-temp-key`}
			})

			AfterEach(func() {
				Expect(key).ToNot(BeNil())
				err := registry.DeleteKey(key, `fake-temp-key`)
				Expect(err).ToNot(HaveOccurred())
			})

			It("fails", func() {
				_, err := ovftool.VmwareInstallPaths(keypaths)

				Expect(err).To(HaveOccurred())
			})
		})
	})

	Context("Ovftool", func() {
		BeforeEach(func() {
			GinkgoT().Setenv("PATH", "")
		})

		It("when ovftool is on the path, its path is returned", func() {
			tmpDir := GinkgoT().TempDir() // automatically cleaned up
			err := os.WriteFile(filepath.Join(tmpDir, "ovftool.exe"), []byte{}, 0700)
			Expect(err).ToNot(HaveOccurred())

			GinkgoT().Setenv("PATH", tmpDir)

			ovfPath, err := ovftool.Ovftool([]string{})
			Expect(err).ToNot(HaveOccurred())
			Expect(ovfPath).To(Equal(filepath.Join(tmpDir, "ovftool.exe")))
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

				err := os.WriteFile(filepath.Join(tmpDir, "ovftool.exe"), []byte{}, 0644)
				Expect(err).ToNot(HaveOccurred())
			})

			It("Returns the path to the ovftool", func() {
				ovfPath, err := ovftool.Ovftool([]string{"not-real-dir", dummyDir, tmpDir})

				Expect(err).ToNot(HaveOccurred())
				Expect(ovfPath).To(Equal(filepath.Join(tmpDir, "ovftool.exe")))
			})
		})
	})
})
