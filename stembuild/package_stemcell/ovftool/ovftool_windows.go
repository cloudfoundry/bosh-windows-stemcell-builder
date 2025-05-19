package ovftool

import (
	"fmt"
	"os/exec"

	"golang.org/x/sys/windows/registry"
)

var keypaths = []string{
	`SOFTWARE\Wow6432Node\VMware, Inc.\VMware Workstation`,
	`SOFTWARE\Wow6432Node\VMware, Inc.\VMware OVF Tool`,
	`SOFTWARE\VMware, Inc.\VMware Workstation`,
	`SOFTWARE\VMware, Inc.\VMware OVF Tool`,
}

// vmwareInstallPaths, returns the install paths of VMware Workstation and
// OVF Tool, which can be installed separately.
func vmwareInstallPaths(keypaths []string) ([]string, error) {
	const regKey = registry.LOCAL_MACHINE
	const access = registry.QUERY_VALUE

	var key registry.Key
	var err error
	for _, path := range keypaths {
		key, err = registry.OpenKey(regKey, path, access)
		if err == nil {
			break
		}
	}
	if err != nil {
		return nil, fmt.Errorf("opening VMware Workstation and OVF Tool registry keys: %s", err)
	}
	defer key.Close() //nolint:errcheck

	var paths []string
	for _, k := range []string{"InstallPath64", "InstallPath"} {
		var s string
		s, _, err = key.GetStringValue(k)
		if err == nil {
			paths = append(paths, s)
		}
	}

	if len(paths) == 0 {
		return nil, fmt.Errorf("could not find VMware Workstation install path in registry: %s", err)
	}
	return paths, nil
}

func SearchPaths() ([]string, error) {
	return vmwareInstallPaths(keypaths)
}

func Ovftool(installPaths []string) (string, error) {
	const name = "ovftool.exe"
	if path, err := exec.LookPath(name); err == nil {
		return path, nil
	}

	for _, dir := range installPaths {
		if path, err := findExecutable(dir, name); err == nil {
			return path, nil
		}
	}
	return "", &exec.Error{Name: name, Err: exec.ErrNotFound}
}
