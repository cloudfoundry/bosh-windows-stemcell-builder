package archive

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"strings"
)

type Zip struct{}

func (z *Zip) Unzip(fileArchive []byte, file string) ([]byte, error) {
	archiveBuffer := bytes.NewReader(fileArchive)
	zipReader, err := zip.NewReader(archiveBuffer, int64(len(fileArchive)))
	if err != nil {
		return nil, fmt.Errorf("invalid zip archive: %s", err)
	}

	for _, f := range zipReader.File {
		if strings.HasSuffix(f.Name, file) {
			// This scope is currently not testable
			r, err := f.Open()
			if err != nil {
				return nil, fmt.Errorf("could not open %s in zip archive: %s", file, err)
			}
			data, err := io.ReadAll(r)
			if err != nil {
				return nil, fmt.Errorf("could not read content of %s in zip archive: %s", file, err)
			}

			return data, nil
		}
	}

	return nil, fmt.Errorf("could not find %s in zip archive", file)
}
