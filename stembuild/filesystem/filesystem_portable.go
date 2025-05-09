//go:build !windows
// +build !windows

package filesystem

import (
	"fmt"
	"syscall"
)

type OSFileSystem struct {
}

func (fs *OSFileSystem) GetAvailableDiskSpace(path string) (uint64, error) {
	fsStat := syscall.Statfs_t{}
	err := syscall.Statfs(path, &fsStat)
	if err != nil {
		return uint64(0), fmt.Errorf("failed to stat %s: %s", path, err)
	}

	// total free bytes available to the user
	return fsStat.Bavail * uint64(fsStat.Bsize), nil
}
