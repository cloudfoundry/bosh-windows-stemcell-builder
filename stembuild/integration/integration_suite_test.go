package integration_test

import (
	"os"
	"testing"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/ovftool"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/test/helpers"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestIntegration(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecs(t, "Integration Suite")
}

var stembuildExecutable string

var _ = SynchronizedBeforeSuite(func() []byte {
	Expect(helpers.CopyRecursive(".", "../test/data")).To(Succeed())
	Expect(CheckOVFToolOnPath()).To(Succeed())

	return nil
}, func(_ []byte) {
})

var _ = SynchronizedAfterSuite(func() {
}, func() {
	Expect(os.RemoveAll("./data")).To(Succeed())
})

func CheckOVFToolOnPath() error {
	searchPaths, err := ovftool.SearchPaths()
	if err != nil {
		return err
	}
	if _, err := ovftool.Ovftool(searchPaths); err != nil {
		return err
	}
	return nil
}
