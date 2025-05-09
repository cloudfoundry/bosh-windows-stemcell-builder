package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func TestCreateManifest(t *testing.T) {
	const winOS = "2012R2"
	const sha1 = "478da1732dba66e67e6a657fdf03b5614c513b04"
	const version = "1200.1"
	const expected = `---
name: bosh-azure-hyperv-windows2012R2-go_agent
version: '1200.1'
bosh_protocol: 1
sha1: 478da1732dba66e67e6a657fdf03b5614c513b04
operating_system: windows2012R2
cloud_properties:
  name: bosh-azure-hyperv-windows2012R2-go_agent
  version: 1200.1
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

	tmpdir, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpdir)

	name := filepath.Join(tmpdir, "stemcell.MF")
	if err := CreateManifest(name, version, winOS, sha1); err != nil {
		t.Error(err)
	}
	src, err := ioutil.ReadFile(name)
	if err != nil {
		t.Error(err)
	}
	if string(src) != expected {
		t.Errorf("CreateManifest --- EXPECTED START ---\n%s\n--- EXPECTED END ---\n"+
			"--- GOT START ---\n%s\n--- GOT END ---\n", expected, string(src))
	}
}
