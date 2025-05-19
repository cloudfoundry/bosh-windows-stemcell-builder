package construct_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/pkg/errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser/commandparserfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/config"
)

var _ = Describe("Factory", func() {
	Describe("GetVMPreparer", func() {
		var (
			factory *construct.Factory
		)

		BeforeEach(func() {
			factory = &construct.Factory{}
		})

		It("should return a New", func() {
			fakeVCenterManager := &commandparserfakes.FakeVCenterManager{}

			sourceConfig := config.SourceConfig{
				GuestVmIp:       "vmIP",
				GuestVMUsername: "vmUser",
				GuestVMPassword: "vmPwd",
				VCenterUrl:      "vCenterUrl",
				VCenterUsername: "vCenterUser",
				VCenterPassword: "vCenterPwd",
				VmInventoryPath: "some-vm-inventory-path",
			}

			vmPreparer, err := factory.New(sourceConfig, fakeVCenterManager)
			Expect(err).ToNot(HaveOccurred())
			Expect(vmPreparer).To(BeAssignableToTypeOf(&construct.VMConstruct{}))
		})

		It("should return a login error when login incorrect to VCenter", func() {
			// setup
			fakeVCenterManager := &commandparserfakes.FakeVCenterManager{}
			loginFailure := errors.New("could not log in")
			fakeVCenterManager.LoginReturns(loginFailure)
			sourceConfig := config.SourceConfig{}

			vmPreparer, err := factory.New(sourceConfig, fakeVCenterManager)

			Expect(vmPreparer).To(BeNil())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("Cannot complete login due to an incorrect vCenter user name or password"))
			Expect(err.Error()).To(ContainSubstring(loginFailure.Error()))
		})
	})
})
