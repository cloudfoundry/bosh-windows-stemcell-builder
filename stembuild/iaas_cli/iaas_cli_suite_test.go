package iaas_cli_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestIaasCli(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "IaasCli Suite")
}
