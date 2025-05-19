package templates_test

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/templates"
)

const (
	vmdkPath         = "FooBarBaz.vmdk"
	virtualHWVersion = 60
)

var _ = Describe("VMX test", func() {
	Context("VMX template render", func() {
		var buf bytes.Buffer

		BeforeEach(func() {
			buf.Reset()
		})

		It("should render a VMX template", func() {
			var buf bytes.Buffer
			err := templates.VMXTemplate(vmdkPath, virtualHWVersion, &buf)
			Expect(err).ToNot(HaveOccurred())

			err = checkVMXTemplate(virtualHWVersion, vmdkPath, buf.String())
			Expect(err).ToNot(HaveOccurred())
		})

		It("should error when VMX filename is unspecified", func() {
			err := templates.VMXTemplate("", 0, &buf)
			Expect(err).To(HaveOccurred())
		})
	})

	Context("VMX template write", func() {
		var tmpDir string

		BeforeEach(func() {
			var err error
			tmpDir, err = os.MkdirTemp("", "vmx-test-")
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			os.RemoveAll(tmpDir) //nolint:errcheck
		})

		It("should write VMX template to file", func() {
			vmxPath := filepath.Join(tmpDir, "FooBarBaz.vmx")

			err := templates.WriteVMXTemplate(vmdkPath, virtualHWVersion, vmxPath)
			Expect(err).ToNot(HaveOccurred())

			b, err := os.ReadFile(vmxPath)
			Expect(err).ToNot(HaveOccurred())

			err = checkVMXTemplate(virtualHWVersion, vmdkPath, string(b))
			Expect(err).ToNot(HaveOccurred())

			err = os.Remove(vmxPath)
			Expect(err).ToNot(HaveOccurred())

			// vmx file is deleted if there is an error
			err = templates.WriteVMXTemplate("", 0, vmxPath)
			Expect(err).To(HaveOccurred())

			_, err = os.Stat(vmxPath)
			Expect(err).To(HaveOccurred())
		})
	})

})

func parseVMX(vmx string) (map[string]string, error) {
	m := make(map[string]string)
	for _, s := range strings.Split(vmx, "\n") {
		if s == "" {
			continue
		}
		n := strings.IndexByte(s, '=')
		if n == -1 {
			return nil, fmt.Errorf("parse vmx: invalid line: %s", s)
		}
		k := strings.TrimSpace(s[:n])
		v, err := strconv.Unquote(strings.TrimSpace(s[n+1:]))
		if err != nil {
			return nil, err
		}
		if _, ok := m[k]; ok {
			return nil, fmt.Errorf("parse vmx: duplicate key: %s", k)
		}
		m[k] = v
	}
	if len(m) == 0 {
		return nil, errors.New("parse vmx: empty vmx")
	}
	return m, nil
}

func checkVMXTemplate(hwVersion int, vmdkPath, vmxContent string) error {
	vmdkPathKeyName := "scsi0:0.fileName"
	hwVersionKeyName := "virtualHW.version"

	m, err := parseVMX(vmxContent)
	if err != nil {
		return err
	}
	if s := m[vmdkPathKeyName]; s != vmdkPath {
		return fmt.Errorf("VMXTemplate: key: %q want: %q got: %q", vmdkPathKeyName, vmdkPath, s)
	}

	expectedHWVersion := strconv.Itoa(hwVersion)
	if s := m[hwVersionKeyName]; s != expectedHWVersion {
		return fmt.Errorf("VMXTemplate: key: %q want: %q got: %q", hwVersionKeyName, expectedHWVersion, s)
	}
	return nil
}
