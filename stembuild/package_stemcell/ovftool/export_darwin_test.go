//go:build darwin
// +build darwin

package ovftool

// This file is used to export private function so that they can be tested
// This should not affect the production API

var HomeDirectory = homeDirectory
