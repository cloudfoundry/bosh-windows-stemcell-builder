package construct_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("VMConnectionValidator", func() {
	var (
		validator         *construct.WinRMConnectionValidator
		fakeRemoteManager *remotemanagerfakes.FakeRemoteManager
	)

	BeforeEach(func() {
		fakeRemoteManager = &remotemanagerfakes.FakeRemoteManager{}

		validator = &construct.WinRMConnectionValidator{
			RemoteManager: fakeRemoteManager,
		}
	})

	Describe("Validate connection to the VM", func() {
		It("can reach VM and can login to VM", func() {
			err := validator.Validate()

			Expect(err).NotTo(HaveOccurred())
			Expect(fakeRemoteManager.CanReachVMCallCount()).To(Equal(1))
			Expect(fakeRemoteManager.CanLoginVMCallCount()).To(Equal(1))
		})

		It("return an error when it cannot reach the VM", func() {
			fakeRemoteManager.CanReachVMReturns(errors.New("could not reach vm"))
			err := validator.Validate()

			Expect(err).To(HaveOccurred())
			Expect(fakeRemoteManager.CanReachVMCallCount()).To(Equal(1))
			Expect(fakeRemoteManager.CanLoginVMCallCount()).To(Equal(0))
		})

		It("return an error when it cannot log into the VM", func() {
			fakeRemoteManager.CanLoginVMReturns(errors.New("login error"))

			err := validator.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring(errors.New("login error").Error()))

			Expect(fakeRemoteManager.CanReachVMCallCount()).To(Equal(1))
			Expect(fakeRemoteManager.CanLoginVMCallCount()).To(Equal(1))
		})
	})

})
