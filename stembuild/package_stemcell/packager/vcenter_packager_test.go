package packager_test

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha1"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/filesystem"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager/packagerfakes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VcenterPackager", func() {

	var outputDir string
	var sourceConfig config.SourceConfig
	var outputConfig config.OutputConfig
	var fakeVcenterClient *packagerfakes.FakeIaasClient

	BeforeEach(func() {
		// Revert to manual cleanup which fails non-catastrophically on windows
		//outputDir = GinkgoT().TempDir() // automatically cleaned up
		outputDir, _ = os.MkdirTemp(os.TempDir(), "vcenter-test-output-dir") //nolint:errcheck

		sourceConfig = config.SourceConfig{Password: "password", URL: "url", Username: "username", VmInventoryPath: "path/valid-vm-name"}
		outputConfig = config.OutputConfig{Os: "2012R2", StemcellVersion: "1200.2", OutputDir: outputDir}
		fakeVcenterClient = &packagerfakes.FakeIaasClient{}
	})

	AfterEach(func() {
		// TODO: remove once GinkgoT().TempDir() is safe on windows
		err := os.RemoveAll(outputDir)
		if err != nil {
			By(fmt.Sprintf("removing '%s' failed: %s", outputDir, err))
		}
	})

	Context("ValidateSourceParameters", func() {
		It("returns an error if the vCenter url is invalid", func() {
			fakeVcenterClient.ValidateUrlReturns(errors.New("vcenter client url error"))
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}

			err := packager.ValidateSourceParameters()

			Expect(err).To(HaveOccurred())
			Expect(fakeVcenterClient.ValidateUrlCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("vcenter client url error"))

		})
		It("returns an error if the vCenter credentials are not valid", func() {
			fakeVcenterClient.ValidateCredentialsReturns(errors.New("vcenter client credential error"))
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}

			err := packager.ValidateSourceParameters()

			Expect(err).To(HaveOccurred())
			Expect(fakeVcenterClient.ValidateCredentialsCallCount()).To(Equal(1))
			Expect(err.Error()).To(ContainSubstring("vcenter client credential error"))
		})

		It("returns an error if VM given does not exist ", func() {
			fakeVcenterClient.FindVMReturns(errors.New("vcenter client vm error"))
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}

			err := packager.ValidateSourceParameters()

			Expect(err).To(HaveOccurred())
			Expect(fakeVcenterClient.FindVMCallCount()).To(Equal(1))
			Expect(err.Error()).To(Equal("vcenter client vm error"))
		})
		It("returns no error if all source parameters are valid", func() {
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}

			err := packager.ValidateSourceParameters()

			Expect(err).NotTo(HaveOccurred())
		})
	})
	Context("ValidateFreeSpace", func() {
		It("is a NOOP", func() {
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}
			err := packager.ValidateFreeSpaceForPackage(&filesystem.OSFileSystem{})

			Expect(err).To(Not(HaveOccurred()))
		})
	})

	Describe("Package", func() {
		var vcenterPackager *packager.VCenterPackager

		AfterEach(func() {
			os.RemoveAll("./valid-vm-name") //nolint:errcheck
			os.RemoveAll("image")           //nolint:errcheck
		})

		BeforeEach(func() {
			vcenterPackager = &packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}

			fakeVcenterClient.ExportVMStub = func(vmInventoryPath string, destination string) error {
				vmName := path.Base(vmInventoryPath)
				os.Mkdir(filepath.Join(destination, vmName), 0777) //nolint:errcheck

				testOvfName := "valid-vm-name.content"
				err := os.WriteFile(filepath.Join(filepath.Join(destination, vmName), testOvfName), []byte(""), 0777)
				Expect(err).NotTo(HaveOccurred())
				return nil
			}
		})

		It("creates a valid stemcell in the output directory", func() {
			err := vcenterPackager.Package()

			Expect(err).To(Not(HaveOccurred()))
			stemcellFilename := packager.StemcellFilename(vcenterPackager.OutputConfig.StemcellVersion, vcenterPackager.OutputConfig.Os)
			stemcellFile := filepath.Join(vcenterPackager.OutputConfig.OutputDir, stemcellFilename)
			_, err = os.Stat(stemcellFile)

			Expect(err).NotTo(HaveOccurred())
			var actualStemcellManifestContent string
			expectedManifestContent := `---
name: bosh-vsphere-esxi-windows2012R2-go_agent
version: '1200.2'
api_version: 3
sha1: %x
operating_system: windows2012R2
cloud_properties:
  infrastructure: vsphere
  hypervisor: esxi
stemcell_formats:
- vsphere-ovf
- vsphere-ova
`
			var fileReader, _ = os.OpenFile(stemcellFile, os.O_RDONLY, 0777) //nolint:errcheck
			gzr, err := gzip.NewReader(fileReader)
			Expect(err).ToNot(HaveOccurred())
			defer gzr.Close() //nolint:errcheck
			tarfileReader := tar.NewReader(gzr)
			count := 0

			for {
				header, err := tarfileReader.Next()
				if err == io.EOF {
					break
				}

				Expect(err).NotTo(HaveOccurred())

				switch filepath.Base(header.Name) {
				case "stemcell.MF":
					buf := new(bytes.Buffer)
					_, err = buf.ReadFrom(tarfileReader)
					Expect(err).NotTo(HaveOccurred())
					count++

					actualStemcellManifestContent = buf.String()

				case "image":
					count++
					actualSha1 := sha1.New()
					io.Copy(actualSha1, tarfileReader) //nolint:errcheck

					expectedManifestContent = fmt.Sprintf(expectedManifestContent, actualSha1.Sum(nil))

				default:

					Fail(fmt.Sprintf("Found unknown file: %s", filepath.Base(header.Name)))
				}
			}
			Expect(count).To(Equal(2))
			Expect(actualStemcellManifestContent).To(Equal(expectedManifestContent))
		})

		It("removes all ethernet and floppy devices", func() {
			fullDeviceList := []string{"video-674", "cdrom-12", "ps2-450", "ethernet-1", "floppy-8000", "floppy-9000", "video-500"}
			expectedDeviceList := []string{"ethernet-1", "floppy-8000", "floppy-9000"}
			fakeVcenterClient.ListDevicesReturns(fullDeviceList, nil)

			err := vcenterPackager.Package()

			Expect(err).NotTo(HaveOccurred())

			for i, device := range expectedDeviceList {
				vmPath, deviceName := fakeVcenterClient.RemoveDeviceArgsForCall(i)
				Expect(vmPath).To(Equal(sourceConfig.VmInventoryPath))
				Expect(deviceName).To(Equal(device))
			}
		})

		It("ejects all CD ROM devices", func() {
			fullDeviceList := []string{"video-674", "cdrom-12", "ps2-450", "ethernet-1", "cdrom-123"}
			expectedDeviceList := []string{"cdrom-12", "cdrom-123"}
			fakeVcenterClient.ListDevicesReturns(fullDeviceList, nil)

			err := vcenterPackager.Package()

			Expect(err).NotTo(HaveOccurred())

			for i, device := range expectedDeviceList {
				vmPath, deviceName := fakeVcenterClient.EjectCDRomArgsForCall(i)
				Expect(vmPath).To(Equal(sourceConfig.VmInventoryPath))
				Expect(deviceName).To(Equal(device))
			}
		})

		It("Throws an error if the VCenter client fails to list devices", func() {
			fakeVcenterClient.ListDevicesReturns([]string{}, errors.New("some client error"))

			err := vcenterPackager.Package()
			Expect(err).To(MatchError("some client error"))
		})

		It("Throws an error if the VCenter client fails to remove a device", func() {
			fakeVcenterClient.ListDevicesReturns([]string{"floppy-8000"}, nil)
			fakeVcenterClient.RemoveDeviceReturns(errors.New("some client error"))

			err := vcenterPackager.Package()
			Expect(err).To(MatchError("some client error"))
		})

		It("Returns a error message if exporting the VM fails", func() {
			packager := packager.VCenterPackager{SourceConfig: sourceConfig, OutputConfig: outputConfig, Client: fakeVcenterClient}
			fakeVcenterClient.ExportVMReturns(errors.New("some client error"))
			err := packager.Package()

			Expect(fakeVcenterClient.ExportVMCallCount()).To(Equal(1))
			vmPath, _ := fakeVcenterClient.ExportVMArgsForCall(0)
			Expect(vmPath).To(Equal(sourceConfig.VmInventoryPath))
			Expect(err.Error()).To(Equal("failed to export the prepared VM"))
		})
	})
})
