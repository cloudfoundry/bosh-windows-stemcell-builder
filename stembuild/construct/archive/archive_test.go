package archive_test

import (
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/assets"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/archive"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Zip", func() {

	zip := new(archive.Zip)

	Describe("Unzip", func() {
		It("should return byte array of the file when it is found in the archive", func() {
			fileArchive := assets.StemcellAutomation
			Expect(fileArchive).ToNot(BeNil())

			r, err := zip.Unzip(fileArchive, "Setup.ps1")
			Expect(err).ToNot(HaveOccurred())
			Expect(r).ToNot(BeNil())
		})

		It("should return an error if the file cannot be found in the archive", func() {
			fileArchive := assets.StemcellAutomation
			Expect(fileArchive).ToNot(BeNil())

			r, err := zip.Unzip(fileArchive, "Setup2.ps1")
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError("could not find Setup2.ps1 in zip archive"))
			Expect(r).To(BeNil())
		})

		It("should return an error if the fileArchive is not a zip file", func() {
			fileArchive := []byte("invalid byte archive")

			r, err := zip.Unzip(fileArchive, "Setup.ps1")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(HavePrefix("invalid zip archive: "))
			Expect(r).To(BeNil())
		})

		It("should return an error if fileArchive is nil", func() {
			_, err := zip.Unzip(nil, "Setup.ps1")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(HavePrefix("invalid zip archive: "))
		})
	})
})
