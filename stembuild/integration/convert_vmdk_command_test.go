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
	Context("with valid vmdk file", func() {
		var osVersion string
		var stembuildVersion string
		var stemcellFilename string
		var inputVmdk string

		BeforeEach(func() {
			inputVmdk = filepath.Join("..", "test", "data", "expected.vmdk")
		})

		Context("when stembuild is built with an invalid version", func() {
			BeforeEach(func() {
				osVersion = "9999"
				stembuildVersion = "9999.0"
			})

			It("it returns an error", func() {
				stembuildExecutable, err := helpers.BuildStembuild(stembuildVersion)
				Expect(err).ToNot(HaveOccurred())


				session := helpers.Stembuild(stembuildExecutable, "package", "--vmdk", inputVmdk)
				Eventually(session).WithTimeout(60*time.Second).Should(Exit(1))
				Eventually(session.Err).Should(Say(fmt.Sprintf(`versioning error; parsed os version is: %s`, osVersion)))
			})
		})

		Context("stembuild is built with an valid version", func() {
			BeforeEach(func() {
				osVersion = "2019"
				stembuildVersion = "2019.0"
			})

			AfterEach(func() {
				Expect(os.Remove(stemcellFilename)).To(Succeed())
			})

			It("creates a valid 2019 stemcell", func() {
				stembuildExecutable, err := helpers.BuildStembuild(stembuildVersion)
				Expect(err).ToNot(HaveOccurred())

				stemcellFilename = fmt.Sprintf("bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", stembuildVersion, osVersion)

				args := []string{"package", "--vmdk", inputVmdk, "--outputDir", "."}
				session := helpers.Stembuild(stembuildExecutable, args...)
				Eventually(session).WithTimeout(60*time.Second).Should(Exit(0),
					fmt.Sprintf(
						"Expected %s %s to exit with code 0, exited with code %d\nout: %s\nerr: %s",
						stembuildExecutable,
						strings.Join(args, " "),
						session.ExitCode(),
						string(session.Out.Contents()),
						string(session.Err.Contents()),
					))
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
