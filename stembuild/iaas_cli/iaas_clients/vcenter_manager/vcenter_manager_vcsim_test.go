package vcenter_manager_test

import (
	"context"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

var _ = Describe("VcenterManager - using a vcsim server", func() {
	var vcsimServer *helpers.VcsimServer
	var vcsimManagerFactory *vcenter_manager.ManagerFactory

	BeforeEach(func() {
		vcsimServer = helpers.NewVcsimServer(`user\name!#`, `password\!#!`)
		vcsimServer.Start()
	})

	AfterEach(func() {
		vcsimServer.Stop()
	})

	BeforeEach(func() {
		vcsimManagerFactory = &vcenter_manager.ManagerFactory{
			Config: vcenter_manager.FactoryConfig{
				VCenterServer:  vcsimServer.Url(),
				Username:       vcsimServer.Username,
				Password:       vcsimServer.Password,
				RootCACertPath: vcsimServer.CertificatePath,
				ClientCreator:  &vcenter_manager.ClientCreator{},
				FinderCreator:  &vcenter_manager.GovmomiFinderCreator{},
			},
		}
	})

	Describe("CloneVM()", func() {
		It("succeeds", func() {
			inventoryPath := "/DC0/vm/DC0_H0_VM0"
			clonePath := "/DC0/vm/DC0_H0_VM0_NewClone"

			ctx := context.TODO()

			vCenterManager, err := vcsimManagerFactory.VCenterManager(ctx)
			Expect(err).ToNot(HaveOccurred())

			err = vCenterManager.Login(ctx)
			Expect(err).ToNot(HaveOccurred())

			vmToClone, err := vCenterManager.FindVM(ctx, inventoryPath)
			Expect(err).ToNot(HaveOccurred())

			err = vCenterManager.CloneVM(ctx, vmToClone, clonePath)
			Expect(err).ToNot(HaveOccurred())

			_, err = vCenterManager.FindVM(ctx, clonePath)
			Expect(err).ToNot(HaveOccurred())
		})
	})

	Describe("Login()", func() {
		It("succeeds", func() {
			ctx := context.TODO()

			vCenterManager, err := vcsimManagerFactory.VCenterManager(ctx)
			Expect(err).ToNot(HaveOccurred())

			err = vCenterManager.Login(ctx)
			Expect(err).ToNot(HaveOccurred())
		})
	})
})
