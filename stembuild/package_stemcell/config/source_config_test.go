package config_test

import (
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("SourceConfig", func() {
	Describe("GetSource", func() {
		It("returns no error when VMDK configured correctly", func() {
			srcConfig := config.SourceConfig{
				Vmdk: "/some/path/to/a/file",
			}
			source, err := srcConfig.GetSource()
			Expect(err).NotTo(HaveOccurred())
			Expect(source).To(Equal(config.VMDK))
		})

		It("returns an error when no configuration provided", func() {
			srcConfig := config.SourceConfig{}
			source, err := srcConfig.GetSource()
			Expect(err).To(MatchError("no configuration was provided"))
			Expect(source).To(Equal(config.NIL))
		})

		It("return no error when vCenter configured correctly", func() {
			srcConfig := config.SourceConfig{
				VmInventoryPath: "/my-datacenter/vm/my-folder/my-vm",
				Username:        "user",
				Password:        "pass",
				URL:             "https://vcenter.test",
			}
			source, err := srcConfig.GetSource()
			Expect(err).NotTo(HaveOccurred())
			Expect(source).To(Equal(config.VCENTER))

		})

		It("returns an error when both VMDK and Vcenter configured", func() {
			srcConfig := config.SourceConfig{
				Vmdk:            "/some/path/to/a/file",
				VmInventoryPath: "/my-datacenter/vm/my-folder/my-vm",
				Username:        "user",
				Password:        "pass",
				URL:             "https://vcenter.test",
			}
			source, err := srcConfig.GetSource()
			Expect(err).To(MatchError("configuration provided for VMDK & vCenter sources"))
			Expect(source).To(Equal(config.NIL))

		})

		It("returns an error when Vcenter configurations only partially specified", func() {
			srcConfig := config.SourceConfig{
				VmInventoryPath: "/my-datacenter/vm/my-folder/my-vm",
				Username:        "user",
				URL:             "https://vcenter.test",
			}
			source, err := srcConfig.GetSource()
			Expect(err).To(MatchError("missing vCenter configurations"))
			Expect(source).To(Equal(config.NIL))
		})

	})

})
