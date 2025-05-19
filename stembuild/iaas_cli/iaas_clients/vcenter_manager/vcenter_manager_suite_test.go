package vcenter_manager_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestVcenterManager(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "VcenterManager Suite")
}

var (
	CertPath string
	cmd      *exec.Cmd
	keyPath  string
)

var _ = BeforeSuite(func() {

	if runtime.GOOS != "windows" {
		workingDir, err := os.Getwd()
		Expect(err).NotTo(HaveOccurred())
		CertPath = filepath.Join(workingDir, "..", "fixtures", "dummycert")
		keyPath = filepath.Join(workingDir, "..", "fixtures", "dummykey")

		vcsimBinary := filepath.Join(os.Getenv("GOPATH"), "bin", "vcsim")

		cmd = exec.Command(vcsimBinary, "-tlscert", CertPath, "-tlskey", keyPath)

		err = cmd.Start()
		Expect(err).ToNot(HaveOccurred())

		time.Sleep(3 * time.Second) // the vcsim server needs a moment to come up
	}

})

var _ = AfterSuite(func() {
	if runtime.GOOS != "windows" && cmd != nil {
		err := cmd.Process.Kill()
		Expect(err).ToNot(HaveOccurred())
	}
})
