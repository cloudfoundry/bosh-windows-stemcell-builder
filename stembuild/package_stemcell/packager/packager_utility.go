package packager

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha1"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

func WriteManifest(manifestContents, manifestPath string) error {
	manifestPath = filepath.Join(manifestPath, "stemcell.MF")

	f, err := os.OpenFile(manifestPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("creating stemcell.MF (%s): %s", manifestPath, err)
	}
	defer f.Close() //nolint:errcheck

	_, err = fmt.Fprint(f, manifestContents)
	if err != nil {
		err = fmt.Errorf("writing stemcell.MF (%s): %w", manifestPath, err)

		removeErr := os.Remove(manifestPath)
		if removeErr != nil {
			err = fmt.Errorf("removing stemcell.MF (%s): %w %w", manifestPath, removeErr, err)
		}

		return err
	}
	return nil
}

func CreateManifest(osVersion, version, sha1sum string) string {
	const format = `---
name: bosh-vsphere-esxi-windows%[1]s-go_agent
version: '%[2]s'
api_version: 3
sha1: %[3]s
operating_system: windows%[1]s
cloud_properties:
  infrastructure: vsphere
  hypervisor: esxi
stemcell_formats:
- vsphere-ovf
- vsphere-ova
`
	return fmt.Sprintf(format, osVersion, version, sha1sum)

}

func TarGenerator(destFileName string, sourceDirName string) (string, error) {
	sourceDir, err := os.Open(sourceDirName)
	if err != nil {
		return "", fmt.Errorf("unable to open %s", sourceDirName)
	}
	defer sourceDir.Close() //nolint:errcheck

	files, err := sourceDir.Readdir(0)
	if err != nil {
		return "", fmt.Errorf("unable to list files in %s", sourceDirName)
	}

	// create tar file
	destFile, err := os.Create(destFileName)
	if err != nil {
		return "", fmt.Errorf("unable to create destination file with name %s", destFileName)
	}
	defer destFile.Close() //nolint:errcheck

	sha1Hash := sha1.New()
	gzw := gzip.NewWriter(io.MultiWriter(destFile, sha1Hash))
	tarWriter := tar.NewWriter(gzw)

	for _, fileInfo := range files {
		if fileInfo.IsDir() {
			continue
		}

		err = writeFileHeader(fileInfo, tarWriter)
		if err != nil {
			return "", fmt.Errorf("unable to write to header of destination tar file %w", err)
		}

		err = writeFilePathToTar(filepath.Join(sourceDir.Name(), fileInfo.Name()), tarWriter)
		if err != nil {
			return "", fmt.Errorf("unable to write contents to destination tar file %w", err)
		}
	}

	err = tarWriter.Close() // can not be deferred; closing the tar writer flushes data; this changes the checksum
	if err != nil {
		return "", fmt.Errorf("unable to close tar file %w", err)
	}
	err = gzw.Close()
	if err != nil {
		return "", fmt.Errorf("unable to close tar file (gzip) %w", err)
	}

	return fmt.Sprintf("%x", sha1Hash.Sum(nil)), nil
}

func writeFileHeader(fileInfo os.FileInfo, tarWriter *tar.Writer) error {
	header := new(tar.Header)
	header.Name = fileInfo.Name()
	header.Size = fileInfo.Size()
	header.Mode = int64(fileInfo.Mode())
	header.ModTime = fileInfo.ModTime()

	return tarWriter.WriteHeader(header)
}

func writeFilePathToTar(filepath string, tarWriter *tar.Writer) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("unable to open file '%s'", filepath)
	}
	defer file.Close() //nolint:errcheck

	_, err = io.Copy(tarWriter, file)
	if err != nil {
		return fmt.Errorf("unable to copy file '%s' to tarball %w", filepath, err)
	}

	return nil
}

func StemcellFilename(version, os string) string {
	return fmt.Sprintf("bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", version, os)
}
