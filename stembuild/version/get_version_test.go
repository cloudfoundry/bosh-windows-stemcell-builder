package version_test

import (
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type VModifier struct {
	newVersionNumber string
}

func (m *VModifier) Modify(v *version.VersionGetter) {
	v.Version = m.newVersionNumber
}

var _ = Describe("Version Utilities", func() {
	Describe("GetVersion", func() {
		It("should return a properly formatted version number", func() {
			versionGetter := version.NewVersionGetter(&VModifier{"1803.123.13"})

			stemcellVersion := versionGetter.GetVersion()
			Expect(stemcellVersion).To(Equal("1803.123"))
		})
	})

	Describe("GetVersionWithPatchNumber", func() {
		It("returns a version number with a patch number when provided", func() {
			versionGetter := version.NewVersionGetter(&VModifier{"2019.5.13"})

			stemcellVersion := versionGetter.GetVersionWithPatchNumber("2")
			Expect(stemcellVersion).To(Equal("2019.5.2"))
		})
	})

	Describe("GetOs", func() {
		It("should return 1803 as OS if given version is 1803", func() {
			versionGetter := version.NewVersionGetter(&VModifier{"1803.5.13"})

			os := versionGetter.GetOs()
			Expect(os).To(Equal("1803"))
		})

		It("should return 2019 as OS if given version is 2019", func() {
			versionGetter := version.NewVersionGetter(&VModifier{"2019.5.13"})

			os := versionGetter.GetOs()
			Expect(os).To(Equal("2019"))
		})

		It("should return 2012R2 as OS if given version is 1200", func() {
			versionGetter := version.NewVersionGetter(&VModifier{"1200.5.13"})

			os := versionGetter.GetOs()
			Expect(os).To(Equal("2012R2"))
		})
	})
})
