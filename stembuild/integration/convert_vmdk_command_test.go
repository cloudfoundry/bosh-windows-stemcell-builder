package integration_test

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"
)

var _ = Describe("Convert VMDK", func() {

	Context("when valid vmdk file", func() {
		var stemcellFilename string
		var inputVmdk string

		Context("stembuild when executed with invalid", func() {
			var version string

			Context("OS value", func() {
				It("of 1709 returns an error", func() {
					version = "1709.0"
					expectedOSVersionInNameANdManifest := "2016"
					var err error
					stembuildExecutable, err = helpers.BuildStembuild("9999.1.0")
					Expect(err).ToNot(HaveOccurred())

					stemcellFilename = fmt.Sprintf("bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", version, expectedOSVersionInNameANdManifest)
					inputVmdk = filepath.Join("..", "test", "data", "expected.vmdk")

					session := helpers.Stembuild(stembuildExecutable, "package", "--vmdk", inputVmdk)
					Eventually(session, 20).Should(Exit(1))
					Eventually(session.Err).Should(Say(`versioning error; parsed os version is: 9999`))
				})

			})
		})

		Context("stembuild when executed", func() {
			var osVersion string
			var version string

			AfterEach(func() {
				Expect(os.Remove(stemcellFilename)).To(Succeed())
			})

			It("creates a valid 2019 stemcell", func() {

				var err error
				stembuildExecutable, err = helpers.BuildStembuild("2019.0.0")
				Expect(err).ToNot(HaveOccurred())

				osVersion = "2019"
				version = "2019.0"
				stemcellFilename = fmt.Sprintf("bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", version, osVersion)
				inputVmdk = filepath.Join("..", "test", "data", "expected.vmdk")

				session := expectStembuildToSucceed("package", "--vmdk", inputVmdk, "--outputDir", ".")
				Eventually(session).Should(Say(`created stemcell: .*\.tgz`))
				Expect(stemcellFilename).To(BeAnExistingFile())

				stemcellDir, err := helpers.ExtractGzipArchive(stemcellFilename)
				Expect(err).NotTo(HaveOccurred())

				manifestFilepath := filepath.Join(stemcellDir, "stemcell.MF")
				manifest, err := helpers.ReadFile(manifestFilepath)
				Expect(err).NotTo(HaveOccurred())

				expectedOs := fmt.Sprintf("operating_system: windows%s", osVersion)
				Expect(manifest).To(ContainSubstring(expectedOs))

				expectedName := fmt.Sprintf("name: bosh-vsphere-esxi-windows%s-go_agent", osVersion)
				Expect(manifest).To(ContainSubstring(expectedName))

				imageFilepath := filepath.Join(stemcellDir, "image")
				imageDir, err := helpers.ExtractGzipArchive(imageFilepath)
				Expect(err).NotTo(HaveOccurred())

				actualVmdkFilepath := filepath.Join(imageDir, "image-disk1.vmdk")
				_, err = os.ReadFile(actualVmdkFilepath)
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})
})

func expectStembuildToSucceed(arguments ...string) *Session {
	session := helpers.Stembuild(stembuildExecutable, arguments...)
	Eventually(session, 60*time.Second).Should(Exit(0),
		fmt.Sprintf(
			"Expected %s %s to exit with code 0, exited with code %d\nout: %s\nerr: %s",
			stembuildExecutable,
			strings.Join(arguments, " "),
			session.ExitCode(),
			string(session.Out.Contents()),
			string(session.Err.Contents()),
		))

	return session
}
