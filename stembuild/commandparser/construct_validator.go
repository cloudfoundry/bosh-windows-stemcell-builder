package commandparser

import (
	"os"
	"path/filepath"
)

type ConstructValidator struct{}

func (c *ConstructValidator) PopulatedArgs(args ...string) bool {
	for _, arg := range args {
		if arg == "" {
			return false
		}
	}
	return true
}

func (c *ConstructValidator) LGPOInDirectory() bool {
	dir, _ := os.Getwd() //nolint:errcheck
	_, err := os.Stat(filepath.Join(dir, "LGPO.zip"))

	return err == nil
}
