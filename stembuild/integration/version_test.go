package integration_test

import (
	"fmt"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"
)

var _ = Describe("Version flag", func() {

	var version = "0.0.0"
	BeforeEach(func() {
		var err error
		stembuildExecutable, err = helpers.BuildStembuild(version)
		Expect(err).NotTo(HaveOccurred())
	})

	Context("when version provided", func() {
		expectedVersion := fmt.Sprintf(`stembuild(\.exe)? version %s, Windows Stemcell Building Tool`, version)

		It("prints version information", func() {
			session := helpers.Stembuild(stembuildExecutable, "--version")

			Eventually(session, 20).Should(Exit(0))
			Eventually(session).Should(Say(expectedVersion))
		})

		It("with command, prints version information and does not run command", func() {
			session := helpers.Stembuild(stembuildExecutable, "--version", "package")

			Eventually(session, 20).Should(Exit(0))
			Eventually(session).Should(Say(expectedVersion))
		})
	})
})
