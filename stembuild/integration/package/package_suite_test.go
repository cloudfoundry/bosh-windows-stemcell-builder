package package_test

import (
	"fmt"
	"os"
	"testing"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestPackage(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Package Suite")
}

const (
	VcenterCACert                     = "VCENTER_CA_CERT"
	baseVMNameEnvVar                  = "PACKAGE_TEST_VM_NAME"
	vcenterURLVariable                = "VCENTER_BASE_URL"
	vcenterAdminCredentialUrlVariable = "VCENTER_ADMIN_CREDENTIAL_URL"
	vcenterFolderVariable             = "VM_FOLDER"
	vcenterStembuildUsernameVariable  = "VCENTER_USERNAME"
	vcenterStembuildPasswordVariable  = "VCENTER_PASSWORD"
	stembuildVersionVariable          = "STEMBUILD_VERSION"
)

var (
	pathToCACert     string
	stembuildVersion string
	executable       string
	baseVMName       string
)

var _ = SynchronizedBeforeSuite(func() []byte {
	rawCA := envMustExist(VcenterCACert)
	t, err := os.CreateTemp("", "ca-cert")
	Expect(err).ToNot(HaveOccurred())
	pathToCACert = t.Name()
	Expect(t.Close()).To(Succeed())
	err = os.WriteFile(pathToCACert, []byte(rawCA), 0666)
	Expect(err).ToNot(HaveOccurred())

	stembuildVersion = helpers.EnvMustExist(stembuildVersionVariable)
	executable, err = helpers.BuildStembuild(stembuildVersion)
	Expect(err).NotTo(HaveOccurred())

	baseVMName = os.Getenv(baseVMNameEnvVar)
	Expect(baseVMName).NotTo(Equal(""), fmt.Sprintf("%s required", baseVMNameEnvVar))
	return nil
}, func(_ []byte) {
})

var _ = SynchronizedAfterSuite(func() {
}, func() {
	if pathToCACert != "" {
		os.RemoveAll(pathToCACert) //nolint:errcheck
	}
})

func envMustExist(variableName string) string {
	result := os.Getenv(variableName)
	if result == "" {
		Fail(fmt.Sprintf("%s must be set", variableName))
	}

	return result
}
