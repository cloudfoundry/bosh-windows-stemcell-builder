package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCreateManifest(t *testing.T) {
	const winOS = "2019"
	const sha1 = "478da1732dba66e67e6a657fdf03b5614c513b04"
	const version = "10.0.17763.410"
	const expected = `---
name: bosh-azure-hyperv-windows2019-go_agent
version: '10.0.17763.410'
api_version: 3
sha1: 478da1732dba66e67e6a657fdf03b5614c513b04
operating_system: windows2019
cloud_properties:
  name: bosh-azure-hyperv-windows2019-go_agent
  version: 10.0.17763.410
  infrastructure: azure
  hypervisor: hyperv
  disk: 40000
  disk_format: vhd
  container_format: bare
  os_type: windows
  os_distro: windows
  architecture: x86_64
  root_device_name: "/dev/sda1"
`

	tmpdir, err := os.MkdirTemp("", "")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpdir)

	name := filepath.Join(tmpdir, "stemcell.MF")
	if err := CreateManifest(name, version, winOS, sha1); err != nil {
		t.Error(err)
	}
	src, err := os.ReadFile(name)
	if err != nil {
		t.Error(err)
	}
	if string(src) != expected {
		t.Errorf("CreateManifest --- EXPECTED START ---\n%s\n--- EXPECTED END ---\n"+
			"--- GOT START ---\n%s\n--- GOT END ---\n", expected, string(src))
	}
}
