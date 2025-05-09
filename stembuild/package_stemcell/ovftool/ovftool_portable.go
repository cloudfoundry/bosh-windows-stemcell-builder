//go:build !darwin && !windows
// +build !darwin,!windows

package ovftool

import "os/exec"

func SearchPaths() ([]string, error) {
	return []string{}, nil
}

// For other OS's, we ignore the parameter, but we need it to
// conform to the signature of the other platform
func Ovftool(_ []string) (string, error) {
	const name = "ovftool"
	return exec.LookPath(name)
}
