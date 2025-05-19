package vcenter_manager_test

import (
	"context"
	"errors"
	"net/url"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/vmware/govmomi/find"
	"github.com/vmware/govmomi/vim25"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager/vcenter_managerfakes"
)

var _ = Describe("VcenterManagerFactory", func() {

	var (
		managerFactory *vcenter_manager.ManagerFactory
	)

	BeforeEach(func() {
		managerFactory = &vcenter_manager.ManagerFactory{}
	})

	Context("VCenterManager", func() {
		It("returns a vcenter manager", func() {

			fakeVimClient := &vim25.Client{}
			fakeClientCreator := &vcenter_managerfakes.FakeVim25ClientCreator{}

			fakeClientCreator.NewClientReturns(fakeVimClient, nil)

			fakeFinder := &find.Finder{}
			fakeFinderCreator := &vcenter_managerfakes.FakeFinderCreator{}
			fakeFinderCreator.NewFinderReturns(fakeFinder)

			managerFactory.SetConfig(vcenter_manager.FactoryConfig{
				VCenterServer:  "example.com",
				Username:       "user",
				Password:       "pass",
				ClientCreator:  fakeClientCreator,
				FinderCreator:  fakeFinderCreator,
				RootCACertPath: "",
			})

			manager, err := managerFactory.VCenterManager(context.TODO())
			Expect(err).NotTo(HaveOccurred())

			Expect(manager).To(BeAssignableToTypeOf(&vcenter_manager.VCenterManager{}))

		})

		It("returns an error if the vcenter server cannot be parsed", func() {
			fakeClientCreator := &vcenter_managerfakes.FakeVim25ClientCreator{}

			managerFactory.SetConfig(vcenter_manager.FactoryConfig{
				VCenterServer: " :", // make soap.ParseURL fail with
				Username:      "user",
				Password:      "pass",
				ClientCreator: fakeClientCreator,
			})

			_, err := managerFactory.VCenterManager(context.TODO())
			var parseErr *url.Error
			ok := errors.As(err, &parseErr)
			Expect(ok).To(BeTrue())
			Expect(parseErr.Op).To(Equal("parse"))
		})

		It("returns an error if a vim25 client cannot be created", func() {

			clientErr := errors.New("can't make a client")
			fakeClientCreator := &vcenter_managerfakes.FakeVim25ClientCreator{}
			fakeClientCreator.NewClientReturns(nil, clientErr)

			managerFactory.SetConfig(vcenter_manager.FactoryConfig{
				VCenterServer: "example.com",
				Username:      "user",
				Password:      "pass",
				ClientCreator: fakeClientCreator,
			})

			_, err := managerFactory.VCenterManager(context.TODO())
			Expect(err).To(MatchError(clientErr))
		})
	})
})
