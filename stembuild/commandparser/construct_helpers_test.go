package commandparser_test

import (
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
)

var _ = Describe("construct_helpers", func() {

	Describe("IsArtifactInDirectory", func() {
		Context("Directory given is valid", func() {

			Describe("LGPO", func() {
				filename := "LGPO.zip"

				Context("LGPO is not present", func() {
					dir := filepath.Join("..", "test", "constructData", "emptyDir")

					It("should return false with no error", func() {
						present, err := commandparser.IsArtifactInDirectory(dir, filename)
						Expect(err).ToNot(HaveOccurred())
						Expect(present).To(BeFalse())
					})
				})

				Context("artifact is present", func() {
					dir := filepath.Join("..", "test", "constructData", "fullDir")

					It("should return true with no error", func() {
						present, err := commandparser.IsArtifactInDirectory(dir, filename)
						Expect(err).ToNot(HaveOccurred())
						Expect(present).To(BeTrue())
					})
				})
			})
		})

		Context("Directory given is not valid", func() {
			filename := "file"
			It("should return an error", func() {
				dir := filepath.Join("..", "test", "constructData", "notExist")
				_, err := commandparser.IsArtifactInDirectory(dir, filename)
				Expect(err).To(HaveOccurred())
			})
		})
	})
})
