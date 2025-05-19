package archive_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestArchive(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Archive Suite")
}
