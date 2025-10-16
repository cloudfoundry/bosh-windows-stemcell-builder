package version_test

import (
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Version Utilities", func() {
	Describe("GetVersion", func() {
		It("should return a properly formatted version number", func() {
			versionGetter := version.Getter{Version: "2019.123.13"}

			stemcellVersion := versionGetter.GetVersion()
			Expect(stemcellVersion).To(Equal("2019.123"))
		})
	})

	Describe("GetVersionWithPatchNumber", func() {
		It("returns a version number with a patch number when provided", func() {
			versionGetter := version.Getter{Version: "2019.5.13"}

			stemcellVersion := versionGetter.GetVersionWithPatchNumber("2")
			Expect(stemcellVersion).To(Equal("2019.5.2"))
		})
	})

	Describe("GetOs", func() {
		It("should returns the first part of a '.' separated string", func() {
			versionGetter := version.Getter{Version: "111.222.333"}

			os := versionGetter.GetOs()
			Expect(os).To(Equal("111"))
		})
	})
})
