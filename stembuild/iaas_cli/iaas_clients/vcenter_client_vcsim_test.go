package iaas_clients_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

var _ = Describe("VcenterClient - using a vcsim server", func() {
	var vcsimServer *helpers.VcsimServer

	BeforeEach(func() {
		vcsimServer = helpers.NewVcsimServer(`user\name!#`, `password\!#!`)
		vcsimServer.Start()
	})

	AfterEach(func() {
		vcsimServer.Stop()
	})

	Describe("ValidateCredentials()", func() {
		It("Succeeds", func() {
			vcsimClient := iaas_clients.NewVcenterClient(
				vcsimServer.Username,
				vcsimServer.Password,
				vcsimServer.Url(),
				vcsimServer.CertificatePath,
				&iaas_cli.GovcRunner{},
			)

			err := vcsimClient.ValidateCredentials()
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
