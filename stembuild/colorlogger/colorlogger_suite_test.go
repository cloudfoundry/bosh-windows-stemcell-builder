package colorlogger_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestColorLogger(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Color Logger Suite")
}
