package templates_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestVMXTemplate(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "VMX Template Suite")
}
