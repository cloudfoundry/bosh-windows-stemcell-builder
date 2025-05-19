package commandparser_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
)

var _ = Describe("ConstructValidator", func() {

	var (
		c commandparser.ConstructValidator
	)
	BeforeEach(func() {
		c = commandparser.ConstructValidator{}
	})

	Describe("PopulatedArgs", func() {
		It("should return true if all arguments are present", func() {
			nonEmptyArgs := c.PopulatedArgs("version", "ip", "username", "password")
			Expect(nonEmptyArgs).To(BeTrue())
		})

		It("should return false if stemcellVersion argument is empty", func() {
			nonEmptyArgs := c.PopulatedArgs("", "ip", "username", "password")
			Expect(nonEmptyArgs).To(BeFalse())
		})

		It("should return false if winrmIp argument is empty", func() {
			nonEmptyArgs := c.PopulatedArgs("version", "", "username", "password")
			Expect(nonEmptyArgs).To(BeFalse())
		})

		It("should return false if username argument is empty", func() {
			nonEmptyArgs := c.PopulatedArgs("version", "ip", "", "password")
			Expect(nonEmptyArgs).To(BeFalse())
		})

		It("should return false if password argument is empty", func() {
			nonEmptyArgs := c.PopulatedArgs("version", "ip", "username", "")
			Expect(nonEmptyArgs).To(BeFalse())
		})
	})

	Describe("LGPOInDirectory", func() {
		wd, _ := os.Getwd() //nolint:errcheck
		LGPOPath := filepath.Join(wd, "LGPO.zip")

		It("should return true if LGPO exists in the directory", func() {
			file, err := os.Create(LGPOPath)
			Expect(err).ToNot(HaveOccurred())
			_, err = os.Stat(LGPOPath)
			Expect(err).ToNot(HaveOccurred())
			file.Close() //nolint:errcheck

			result := c.LGPOInDirectory()

			Expect(result).To(BeTrue())

			err = os.Remove(LGPOPath)
			Expect(err).ToNot(HaveOccurred())
		})

		It("should return false if LGPO doesn't exist in the directory", func() {
			result := c.LGPOInDirectory()

			Expect(result).To(BeFalse())
		})
	})
})
