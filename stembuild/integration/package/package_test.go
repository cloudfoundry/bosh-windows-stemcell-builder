package package_test

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha1"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"github.com/vmware/govmomi/cli"
	_ "github.com/vmware/govmomi/cli/vm"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"
)

var _ = Describe("Package", func() {
	var (
		workingDir                string
		vmPath                    string
		vcenterURL                string
		vcenterAdminCredentialUrl string
		vcenterStembuildUsername  string
		vcenterStembuildPassword  string
	)

	BeforeEach(func() {
		vcenterFolder := helpers.EnvMustExist(vcenterFolderVariable)
		packageTestVMName := fmt.Sprintf("stembuild-package-test-%d", rand.Int())

		baseVMWithPath := strings.Join([]string{vcenterFolder, baseVMName}, "/")
		vmPath = strings.Join([]string{vcenterFolder, packageTestVMName}, "/")

		vcenterAdminCredentialUrl = helpers.EnvMustExist(vcenterAdminCredentialUrlVariable)

		cli.Run([]string{
			"vm.clone",
			"-vm", baseVMWithPath,
			"-folder", vcenterFolder,
			"-on=false",
			"-u", vcenterAdminCredentialUrl,
			"-tls-ca-certs", pathToCACert,
			packageTestVMName,
		})

		vcenterURL = helpers.EnvMustExist(vcenterURLVariable)
		vcenterStembuildUsername = helpers.EnvMustExist(vcenterStembuildUsernameVariable)
		vcenterStembuildPassword = helpers.EnvMustExist(vcenterStembuildPasswordVariable)

		// workingDir = GinkgoT().TempDir() // automatically cleaned up
		var err error
		workingDir, err = os.MkdirTemp(os.TempDir(), "stembuild-package-test")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		// TODO: remove once GinkgoT().TempDir() is safe on windows
		err := os.RemoveAll(workingDir)
		if err != nil {
			By(fmt.Sprintf("removing '%s' failed: %s", workingDir, err))
		}

		if vmPath != "" {
			cli.Run([]string{
				"vm.destroy",
				"-vm.ipath", vmPath,
				"-u", vcenterAdminCredentialUrl,
				"-tls-ca-certs", pathToCACert,
			})
		}
	})

	It("generates a stemcell with the correct shasum", func() {
		session := helpers.RunCommandInDir(
			workingDir,
			executable, "package",
			"-vcenter-url", vcenterURL,
			"-vcenter-username", vcenterStembuildUsername,
			"-vcenter-password", vcenterStembuildPassword,
			"-vm-inventory-path", vmPath,
			"-vcenter-ca-certs", pathToCACert,
		)

		Eventually(session, 60*time.Minute, 5*time.Second).Should(gexec.Exit(0))
		var out []byte
		session.Out.Write(out) //nolint:errcheck
		By(fmt.Sprintf("session.Out: '%s'", string(out)))

		expectedOSVersion := strings.Split(stembuildVersion, ".")[0]
		expectedStemcellVersion := strings.Split(stembuildVersion, ".")[:2]

		expectedFilename := fmt.Sprintf(
			"bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", strings.Join(expectedStemcellVersion, "."), expectedOSVersion)

		stemcellPath := filepath.Join(workingDir, expectedFilename)

		image, err := os.Create(filepath.Join(workingDir, "image"))
		Expect(err).NotTo(HaveOccurred())
		copyFileFromTar(stemcellPath, "image", image)

		vmdkSha := sha1.New()
		ovfSha := sha1.New()

		imageMF, err := os.Create(filepath.Join(workingDir, "image.mf"))
		Expect(err).NotTo(HaveOccurred())

		copyFileFromTar(filepath.Join(workingDir, "image"), ".mf", imageMF)
		copyFileFromTar(filepath.Join(workingDir, "image"), ".vmdk", vmdkSha)
		copyFileFromTar(filepath.Join(workingDir, "image"), ".ovf", ovfSha)

		imageMFFile, err := helpers.ReadFile(filepath.Join(workingDir, "image.mf"))
		Expect(err).NotTo(HaveOccurred())
		Expect(imageMFFile).To(ContainSubstring(fmt.Sprintf("%x", vmdkSha.Sum(nil))))
		Expect(imageMFFile).To(ContainSubstring(fmt.Sprintf("%x", ovfSha.Sum(nil))))

		By("and the stemcell manifest specifies agent api_version 3", func() {
			stemcellManifestPath, err := os.Create(filepath.Join(workingDir, "stemcell.MF"))
			Expect(err).NotTo(HaveOccurred())
			copyFileFromTar(stemcellPath, "stemcell.MF", stemcellManifestPath)

			stemcellManifest, err := helpers.ReadFile(stemcellManifestPath.Name())
			Expect(err).NotTo(HaveOccurred())
			Expect(stemcellManifest).To(ContainSubstring("api_version: 3"))
		})
	})

	It("generates a stemcell with a patch number when specified", func() {
		session := helpers.RunCommandInDir(
			workingDir,
			executable, "package",
			"-vcenter-url", vcenterURL,
			"-vcenter-username", vcenterStembuildUsername,
			"-vcenter-password", vcenterStembuildPassword,
			"-vm-inventory-path", vmPath,
			"-patch-version", "5",
			"-vcenter-ca-certs", pathToCACert,
		)

		Eventually(session, 60*time.Minute, 5*time.Second).Should(gexec.Exit(0))
		var out []byte
		session.Out.Write(out) //nolint:errcheck
		By(fmt.Sprintf("session.Out: '%s'", string(out)))

		expectedOSVersion := strings.Split(stembuildVersion, ".")[0]
		expectedStemcellVersion := strings.Split(stembuildVersion, ".")[:2]
		expectedStemcellVersion = append(expectedStemcellVersion, "5")

		expectedFilename := fmt.Sprintf(
			"bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz", strings.Join(expectedStemcellVersion, "."), expectedOSVersion)

		stemcellPath := filepath.Join(workingDir, expectedFilename)
		Expect(stemcellPath).To(BeAnExistingFile())

		stemcellManifestPath, err := os.Create(filepath.Join(workingDir, "stemcell.MF"))
		Expect(err).NotTo(HaveOccurred())

		copyFileFromTar(stemcellPath, "stemcell.MF", stemcellManifestPath)

		stemcellManifest, err := helpers.ReadFile(stemcellManifestPath.Name())
		Expect(err).NotTo(HaveOccurred())
		Expect(stemcellManifest).To(ContainSubstring(strings.Join(expectedStemcellVersion, ".")))
	})
})

func copyFileFromTar(t string, f string, w io.Writer) {
	z, err := os.OpenFile(t, os.O_RDONLY, 0777)
	Expect(err).NotTo(HaveOccurred())
	gzr, err := gzip.NewReader(z)
	Expect(err).NotTo(HaveOccurred())
	defer gzr.Close() //nolint:errcheck

	r := tar.NewReader(gzr)
	for {
		header, err := r.Next()
		if err == io.EOF {
			break
		}
		Expect(err).NotTo(HaveOccurred())

		if strings.Contains(header.Name, f) {
			_, err = io.Copy(w, r)
			Expect(err).NotTo(HaveOccurred())
		}
	}
}
