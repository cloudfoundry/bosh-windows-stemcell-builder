package filesystem

import (
	"fmt"
	"syscall"
	"unsafe"
)

type OSFileSystem struct {
}

func (*OSFileSystem) GetAvailableDiskSpace(path string) (uint64, error) {
	h, err := syscall.LoadDLL("kernel32.dll") // This will throw a panic if it fails. Suggest to use LoadDLL instead
	if err != nil {
		return uint64(0), fmt.Errorf("failed to load kernel32 DLL: %s", err)
	}
	c, err := h.FindProc("GetDiskFreeSpaceExW") // This will throw a panic if it fails. Suggest to use FindProc instead
	if err != nil {
		return uint64(0), fmt.Errorf("failed to find GetDiskFreeSpaceExW procedure: %s", err)
	}

	var totalBytes uint64    // total bytes
	var freeBytes uint64     // total free bytes
	var userFreeBytes uint64 // total free bytes available to the user

	ptr, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return uint64(0), fmt.Errorf("failed to convert: %s", err)
	}

	r1, _, err := c.Call(uintptr(unsafe.Pointer(ptr)), uintptr(unsafe.Pointer(&userFreeBytes)), uintptr(unsafe.Pointer(&totalBytes)), uintptr(unsafe.Pointer(&freeBytes)))
	if r1 != 1 && err != nil {
		return uint64(0), fmt.Errorf("failed to call OS: %s", err)
	}
	return userFreeBytes, nil
}
