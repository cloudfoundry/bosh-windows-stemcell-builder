package packager_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager"
)

var _ = Describe("Factory", func() {

	outputConfig := config.OutputConfig{
		Os:              "2012R2",
		StemcellVersion: "1200.00",
		OutputDir:       "/tmp/outputDir",
	}

	var packagerFactory *packager.Factory
	var logger colorlogger.Logger

	BeforeEach(func() {
		packagerFactory = &packager.Factory{}
		logger = colorlogger.New(0, false, GinkgoWriter)
	})

	Describe("GetPackager", func() {
		Context("When VMDK is specified and no vCenter credentials are given", func() {
			It("returns a VMDK packager with no error", func() {
				sourceConfig := config.SourceConfig{
					Vmdk: "path/to/a/vmdk",
				}

				actualPackager, err := packagerFactory.NewPackager(sourceConfig, outputConfig, logger)
				Expect(err).NotTo(HaveOccurred())

				Expect(actualPackager).To(BeAssignableToTypeOf(&packager.VmdkPackager{}))
				Expect(actualPackager).NotTo(BeAssignableToTypeOf(&packager.VCenterPackager{}))
			})
		})

		Context("When all vCenter credentials are given and no VMDK is specified", func() {
			It("returns a vCenter packager with no error", func() {
				sourceConfig := config.SourceConfig{
					Username:        "user",
					Password:        "pass",
					URL:             "some-url",
					VmInventoryPath: "some-vm-inventory-path",
				}

				actualPackager, err := packagerFactory.NewPackager(sourceConfig, outputConfig, logger)
				Expect(err).NotTo(HaveOccurred())

				Expect(actualPackager).To(BeAssignableToTypeOf(&packager.VCenterPackager{}))
				Expect(actualPackager).NotTo(BeAssignableToTypeOf(&packager.VmdkPackager{}))
			})
		})

		Context("When at least one vCenter configuration and VMDK are both specified", func() {
			It("returns an error", func() {
				sourceConfig := config.SourceConfig{
					Vmdk:            "path/to/a/vmdk",
					VmInventoryPath: "some-vm",
				}

				packager, err := packagerFactory.NewPackager(sourceConfig, outputConfig, logger)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("configuration provided for VMDK & vCenter sources"))
				Expect(packager).To(BeNil())
			})
		})

		Context("When partial vCenter credentials are given and no VMDK is specified", func() {
			It("returns an error", func() {
				sourceConfig := config.SourceConfig{
					VmInventoryPath: "some-vm",
					Password:        "pass",
					URL:             "some-url",
				}

				packager, err := packagerFactory.NewPackager(sourceConfig, outputConfig, logger)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("missing vCenter configurations"))
				Expect(packager).To(BeNil())
			})
		})

		Context("When no configuration has been provided", func() {
			It("returns an error", func() {
				sourceConfig := config.SourceConfig{}

				packager, err := packagerFactory.NewPackager(sourceConfig, outputConfig, logger)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("no configuration was provided"))
				Expect(packager).To(BeNil())
			})
		})
	})
})
