package config_test

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("OutputConfig", func() {
	Describe("os", func() {
		Context("no os specified", func() {
			It("should be invalid", func() {
				valid := config.IsValidOS("")
				Expect(valid).To(BeFalse())
			})
		})

		Context("a supported os is specified", func() {
			It("2016 should be valid", func() {
				valid := config.IsValidOS("2016")
				Expect(valid).To(BeTrue())
			})

			It("2012R2 should be valid", func() {
				valid := config.IsValidOS("2012R2")
				Expect(valid).To(BeTrue())
			})

			It("1803 should be valid", func() {
				valid := config.IsValidOS("1803")
				Expect(valid).To(BeTrue())
			})

			It("2019 should be valid", func() {
				valid := config.IsValidOS("2019")
				Expect(valid).To(BeTrue())
			})
		})

		Context("something other than a supported os is specified", func() {
			It("should be invalid", func() {
				valid := config.IsValidOS("bad-thing")
				Expect(valid).To(BeFalse())
			})

			It("1709 should be invalid", func() {
				valid := config.IsValidOS("1709")
				Expect(valid).To(BeFalse())
			})
		})
	})

	Describe("stemcell version", func() {
		Context("no stemcell version specified", func() {
			It("should be invalid", func() {
				valid := config.IsValidStemcellVersion("")
				Expect(valid).To(BeFalse())
			})
		})

		Context("stemcell version specified is valid pattern", func() {
			It("should be valid", func() {
				versions := []string{"4.4", "4.4-build.1", "4.4.4", "4.4.4-build.4"}
				for _, version := range versions {
					valid := config.IsValidStemcellVersion(version)
					Expect(valid).To(BeTrue())
				}
			})
		})

		Context("stemcell version specified is invalid pattern", func() {
			It("should be invalid", func() {
				valid := config.IsValidStemcellVersion("4.4.4.4")
				Expect(valid).To(BeFalse())
			})
		})
	})

	Describe("validateOutputDir", func() {
		var outputDir string

		Context("no dir given", func() {
			BeforeEach(func() {
				outputDir = ""
			})

			It("should be an error", func() {
				err := config.ValidateOrCreateOutputDir("")
				Expect(err).To(HaveOccurred())
			})
		})

		Context("with a valid relative directory", func() {
			var originalWorkingDir, workingDir string

			BeforeEach(func() {
				var err error
				originalWorkingDir, err = os.Getwd()
				Expect(err).NotTo(HaveOccurred())

				outputDir = filepath.Join(".", "some-directory")

				workingDir = GinkgoT().TempDir()
				err = os.Chdir(workingDir)
				Expect(err).ToNot(HaveOccurred())
			})

			AfterEach(func() {
				Expect(os.Chdir(originalWorkingDir)).To(Succeed())
			})

			Context("that does not exist", func() {
				It("should create the directory and not fail", func() {
					err := config.ValidateOrCreateOutputDir(outputDir)
					Expect(err).ToNot(HaveOccurred())

					_, err = os.Stat(outputDir)
					Expect(err).ToNot(HaveOccurred())
				})
			})

			Context("that already exists", func() {
				BeforeEach(func() {
					err := os.MkdirAll(outputDir, os.ModePerm)
					Expect(err).ToNot(HaveOccurred())
				})

				It("should not fail", func() {
					_, err := os.Stat(outputDir)
					Expect(err).ToNot(HaveOccurred())

					err = config.ValidateOrCreateOutputDir(outputDir)
					Expect(err).ToNot(HaveOccurred())
				})
			})

			Context("when intermediate directories do not exist", func() {
				It("should be an error", func() {
					missingIntermediateDir := filepath.Join(outputDir, "does-not", "exist")
					err := config.ValidateOrCreateOutputDir(missingIntermediateDir)
					Expect(err).To(HaveOccurred())
				})
			})
		})

		Context("with valid absolute directory", func() {
			BeforeEach(func() {
				outputDir = GinkgoT().TempDir()
			})

			It("should not fail", func() {
				err := config.ValidateOrCreateOutputDir(outputDir)
				Expect(err).ToNot(HaveOccurred())
			})

			Context("when intermediate directories do not exist", func() {
				It("should be an error", func() {
					missingIntermediateDir := filepath.Join(outputDir, "does-not", "exist")
					err := config.ValidateOrCreateOutputDir(missingIntermediateDir)
					Expect(err).To(HaveOccurred())
				})
			})
		})
	})
})
