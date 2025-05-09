package packager

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha1"
	"fmt"
	"io"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Packager Utility", func() {
	Context("TarGenerator", func() {
		var sourceDir string
		var destinationDir string

		BeforeEach(func() {
			// Revert to manual cleanup which fails non-catastrophically on windows
			//sourceDir = GinkgoT().TempDir()      // automatically cleaned up
			//destinationDir = GinkgoT().TempDir() // automatically cleaned up
			sourceDir, _ = os.MkdirTemp(os.TempDir(), "packager-utility-test-source")           //nolint:errcheck
			destinationDir, _ = os.MkdirTemp(os.TempDir(), "packager-utility-test-destination") //nolint:errcheck
		})

		AfterEach(func() {
			// TODO: remove once GinkgoT().TempDir() is safe on windows
			err := os.RemoveAll(sourceDir)
			if err != nil {
				By(fmt.Sprintf("removing '%s' failed: %s", sourceDir, err))
			}
			err = os.RemoveAll(destinationDir)
			if err != nil {
				By(fmt.Sprintf("removing '%s' failed: %s", destinationDir, err))
			}
		})

		It("should tar all files inside provided folder and return its sha1", func() {
			err := os.WriteFile(filepath.Join(sourceDir, "file1"), []byte("file1 content\n"), 0777)
			Expect(err).NotTo(HaveOccurred())
			err = os.WriteFile(filepath.Join(sourceDir, "file2"), []byte("file2 content\n"), 0777)
			Expect(err).NotTo(HaveOccurred())
			fileContentMap := make(map[string]string)
			fileContentMap["file1"] = "file1 content\n"
			fileContentMap["file2"] = "file2 content\n"

			tarball := filepath.Join(destinationDir, "tarball")

			sha1Sum, err := TarGenerator(tarball, sourceDir)

			Expect(err).NotTo(HaveOccurred())

			_, err = os.Stat(tarball)
			Expect(err).NotTo(HaveOccurred())
			var fileReader, _ = os.OpenFile(tarball, os.O_RDONLY, 0777) //nolint:errcheck

			gzr, err := gzip.NewReader(fileReader)
			Expect(err).ToNot(HaveOccurred())
			defer func() { Expect(gzr.Close()).To(Succeed()) }()

			tarReader := tar.NewReader(gzr)
			count := 0
			for {
				header, err := tarReader.Next()
				if err == io.EOF {
					break
				}
				count++
				Expect(err).NotTo(HaveOccurred())
				buf := new(bytes.Buffer)
				_, err = buf.ReadFrom(tarReader)
				if err != nil {
					break
				}
				Expect(fileContentMap[header.Name]).To(Equal(buf.String()))
			}
			Expect(count).To(Equal(2))

			tarballFile, err := os.Open(tarball)
			Expect(err).NotTo(HaveOccurred())
			defer func() { Expect(tarballFile.Close()).To(Succeed()) }()

			expectedSha1 := sha1.New()
			_, err = io.Copy(expectedSha1, tarballFile)
			Expect(err).NotTo(HaveOccurred())

			expectedSha1Sum := fmt.Sprintf("%x", expectedSha1.Sum(nil))
			Expect(sha1Sum).To(Equal(expectedSha1Sum))
		})
	})

	Context("CreateManifest", func() {
		It("Creates a manifest correctly", func() {
			expectedManifest := `---
name: bosh-vsphere-esxi-windows1-go_agent
version: 'version'
api_version: 3
sha1: sha1sum
operating_system: windows1
cloud_properties:
  infrastructure: vsphere
  hypervisor: esxi
stemcell_formats:
- vsphere-ovf
- vsphere-ova
`
			result := CreateManifest("1", "version", "sha1sum")
			Expect(result).To(Equal(expectedManifest))
		})
	})

	Context("StemcellFileName", func() {
		It("formats a file name appropriately", func() {
			expectedName := "bosh-stemcell-1200.1-vsphere-esxi-windows2012R2-go_agent.tgz"
			Expect(StemcellFilename("1200.1", "2012R2")).To(Equal(expectedName))
		})
	})
})
