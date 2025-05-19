package packager_test

import (
	"crypto/sha1"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	mockfilesystem "github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/filesystem/mock"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

var _ = Describe("VmdkPackager", func() {
	var stembuildConfig config.VmdkOptions
	var vmdkPackager packager.VmdkPackager

	BeforeEach(func() {
		stembuildConfig = config.VmdkOptions{
			OSVersion: "2012R2",
			Version:   "1200.1",
		}

		vmdkPackager = packager.VmdkPackager{
			Stop:         make(chan struct{}),
			BuildOptions: stembuildConfig,
			Logger:       colorlogger.New(0, false, GinkgoWriter),
		}
	})

	Describe("vmdk", func() {
		Context("valid vmdk file specified", func() {
			It("should be valid", func() {
				vmdk, err := os.CreateTemp("", "temp.vmdk")
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(vmdk.Name()) //nolint:errcheck

				valid, err := packager.IsValidVMDK(vmdk.Name())
				Expect(err).To(BeNil())
				Expect(valid).To(BeTrue())
			})
		})

		Context("invalid vmdk file specified", func() {
			It("should be invalid", func() {
				valid, err := packager.IsValidVMDK(filepath.Join("..", "out", "invalid"))
				Expect(err).To(HaveOccurred())
				Expect(valid).To(BeFalse())
			})
		})
	})

	Describe("CreateImage", func() {
		It("successfully creates an image tarball", func() {
			vmdkPackager.BuildOptions.VMDKFile = filepath.Join("..", "..", "test", "data", "expected.vmdk")
			err := vmdkPackager.CreateImage()
			Expect(err).NotTo(HaveOccurred())

			// the image will be saved to the VmdkPackager's temp directory
			tmpdir, err := vmdkPackager.TempDir()
			Expect(err).NotTo(HaveOccurred())

			outputImagePath := filepath.Join(tmpdir, "image")
			Expect(vmdkPackager.Image).To(Equal(outputImagePath))

			// Make sure the sha1 sum is correct
			h := sha1.New()
			f, err := os.Open(vmdkPackager.Image)
			Expect(err).NotTo(HaveOccurred())

			_, err = io.Copy(h, f)
			Expect(err).NotTo(HaveOccurred())

			actualShasum := fmt.Sprintf("%x", h.Sum(nil))
			Expect(vmdkPackager.Sha1sum).To(Equal(actualShasum))

			// expect the image ova to contain only the following file names
			expectedNames := []string{
				"image.ovf",
				"image.mf",
				"image-disk1.vmdk",
			}

			imageDir, err := helpers.ExtractGzipArchive(vmdkPackager.Image)
			Expect(err).NotTo(HaveOccurred())
			list, err := os.ReadDir(imageDir)
			Expect(err).NotTo(HaveOccurred())

			var names []string
			infos := make(map[string]os.DirEntry)
			for _, fi := range list {
				names = append(names, fi.Name())
				infos[fi.Name()] = fi
			}
			Expect(names).To(ConsistOf(expectedNames))

			// the vmx template should generate an ovf file that
			// does not contain an ethernet section.
			ovf := filepath.Join(imageDir, "image.ovf")
			ovfFile, err := helpers.ReadFile(ovf)
			Expect(err).NotTo(HaveOccurred())
			Expect(ovfFile).NotTo(MatchRegexp(`(?i)ethernet`))
		})
	})

	Describe("ValidateFreeSpaceForPackage", func() {
		var (
			mockCtrl       *gomock.Controller
			mockFileSystem *mockfilesystem.MockFileSystem
		)

		Context("When VMDK file is invalid", func() {
			It("returns an error", func() {
				vmdkPackager.BuildOptions.VMDKFile = ""

				mockCtrl = gomock.NewController(GinkgoT())
				mockFileSystem = mockfilesystem.NewMockFileSystem(mockCtrl)

				err := vmdkPackager.ValidateFreeSpaceForPackage(mockFileSystem)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("could not get vmdk info"))

			})
		})

		Context("When filesystem has enough free space for stemcell (twice the size of the expected free space)", func() {
			It("does not return an error", func() {
				vmdkPackager.BuildOptions.VMDKFile = filepath.Join("..", "..", "test", "data", "expected.vmdk")

				mockCtrl = gomock.NewController(GinkgoT())
				mockFileSystem = mockfilesystem.NewMockFileSystem(mockCtrl)

				vmdkFile, err := os.Stat(vmdkPackager.BuildOptions.VMDKFile)
				Expect(err).ToNot(HaveOccurred())

				testVmdkSize := vmdkFile.Size()
				expectFreeSpace := uint64(testVmdkSize)*2 + (packager.Gigabyte / 2)

				directoryPath := filepath.Dir(vmdkPackager.BuildOptions.VMDKFile)
				mockFileSystem.EXPECT().GetAvailableDiskSpace(directoryPath).Return(uint64(expectFreeSpace*2), nil).AnyTimes()

				err = vmdkPackager.ValidateFreeSpaceForPackage(mockFileSystem)
				Expect(err).To(Not(HaveOccurred()))

			})
		})
		Context("When filesystem does not have enough free space for stemcell (half the size of the expected free space", func() {
			It("returns error", func() {
				vmdkPackager.BuildOptions.VMDKFile = filepath.Join("..", "..", "test", "data", "expected.vmdk")

				mockCtrl = gomock.NewController(GinkgoT())
				mockFileSystem = mockfilesystem.NewMockFileSystem(mockCtrl)

				vmdkFile, err := os.Stat(vmdkPackager.BuildOptions.VMDKFile)
				Expect(err).ToNot(HaveOccurred())

				testVmdkSize := vmdkFile.Size()
				expectFreeSpace := uint64(testVmdkSize)*2 + (packager.Gigabyte / 2)

				directoryPath := filepath.Dir(vmdkPackager.BuildOptions.VMDKFile)
				mockFileSystem.EXPECT().GetAvailableDiskSpace(directoryPath).Return(uint64(expectFreeSpace/2), nil).AnyTimes()

				err = vmdkPackager.ValidateFreeSpaceForPackage(mockFileSystem)

				Expect(err).To(HaveOccurred())

				expectedErrorMsg := "Not enough space to create stemcell. Free up "
				Expect(err.Error()).To(ContainSubstring(expectedErrorMsg))
			})
		})

		Context("When filesystem fails to provide free space", func() {
			It("returns error specifying that given disk could not provide free space", func() {
				vmdkPackager.BuildOptions.VMDKFile = filepath.Join("..", "..", "test", "data", "expected.vmdk")

				mockCtrl = gomock.NewController(GinkgoT())
				mockFileSystem = mockfilesystem.NewMockFileSystem(mockCtrl)

				directoryPath := filepath.Dir(vmdkPackager.BuildOptions.VMDKFile)
				mockFileSystem.EXPECT().GetAvailableDiskSpace(directoryPath).Return(uint64(4), errors.New("some error")).AnyTimes()

				err := vmdkPackager.ValidateFreeSpaceForPackage(mockFileSystem)

				Expect(err).To(HaveOccurred())
				expectedErrorMsg := "could not check free space on disk: "
				Expect(err.Error()).To(ContainSubstring(expectedErrorMsg))
			})
		})
	})
})
