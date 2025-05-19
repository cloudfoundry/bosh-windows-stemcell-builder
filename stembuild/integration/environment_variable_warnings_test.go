package integration_test

import (
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"
)

var _ = Describe("Environment Variables Warning", func() {
	var (
		stembuildExecutable string
	)
	BeforeEach(func() {
		var err error
		stembuildExecutable, err = helpers.BuildStembuild("0.0.0")
		Expect(err).NotTo(HaveOccurred())
	})

	When("Environment variables starting with GOVC_* or GOVMOMI_* are set", func() {
		It("should print a warning for each GOVC_* environment variable", func() {
			session := helpers.StembuildWithEnv(map[string]string{"GOVC_BANANA": "I AM A BANANA", "GOVMOMI_POTATO": "THIS IS A POTATO"}, stembuildExecutable, "--version")
			Eventually(session.Err).Should(Say("Warning: The following environment variable is set and might override flags provided to stembuild: GOVC_BANANA\n"))
			Consistently(session.Err).ShouldNot(Say("I AM A BANANA"))
			Eventually(session).Should(Exit(0))
		})

		It("should print a warning for each GOVMOMI_* environment variable", func() {
			session := helpers.StembuildWithEnv(map[string]string{"GOVC_BANANA": "I AM A BANANA", "GOVMOMI_POTATO": "THIS IS A POTATO"}, stembuildExecutable, "--version")
			Eventually(session.Err).Should(Say("Warning: The following environment variable is set and might override flags provided to stembuild: GOVMOMI_POTATO\n"))
			Consistently(session.Err).ShouldNot(Say("THIS IS A POTATO"))
			Eventually(session).Should(Exit(0))
		})
	})
})
