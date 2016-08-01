package bosh_windows_acceptance_tests_test

import (
	"bytes"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

func init() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.SetOutput(GinkgoWriter)
}

var manifestTemplate = `
---
name: {{.DeploymentName}}
director_uuid: {{.DirectorUUID}}

releases:
- name: {{.ReleaseName}}
  version: latest

stemcells:
- alias: default
  name: {{.StemcellName}}
  version: latest

update:
  canaries: 0
  canary_watch_time: 60000
  update_watch_time: 60000
  max_in_flight: 2

instance_groups:
- name: errand
  instances: 1
  stemcell: default
  lifecycle: errand
  azs: [default]
  vm_type: xlarge
  vm_extensions: []
  networks:
  - name: integration-tests
  jobs:
  - name: {{.JobName}}
    release: {{.ReleaseName}}
`

type ManifestProperties struct {
	DeploymentName string
	DirectorUUID   string
	ReleaseName    string
	StemcellName   string
	JobName        string
}

func generateManifest(deploymentName string) ([]byte, error) {
	uuid := os.Getenv("DIRECTOR_UUID")
	if uuid == "" {
		return nil, fmt.Errorf("invalid director UUID: %q", uuid)
	}
	stemcell := os.Getenv("STEMCELL_NAME")
	if stemcell == "" {
		return nil, fmt.Errorf("invalid stemcell name: %q", stemcell)
	}
	manifestProperties := ManifestProperties{
		DeploymentName: deploymentName,
		DirectorUUID:   uuid,
		ReleaseName:    "errand-release",
		StemcellName:   stemcell,
		JobName:        "errand",
	}
	templ, err := template.New("").Parse(manifestTemplate)
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	err = templ.Execute(&buf, manifestProperties)
	return buf.Bytes(), err
}

type BoshCommand struct {
	DirectorIP string
	CertPath   string // Path to CA CERT file, if any
	Timeout    time.Duration
}

func NewBoshCommand(DirectorIP, CertPath string) *BoshCommand {
	return &BoshCommand{
		DirectorIP: DirectorIP,
		CertPath:   CertPath,
		Timeout:    time.Minute * 15,
	}
}

func (c *BoshCommand) args(command string) []string {
	args := strings.Split(command, " ")
	args = append([]string{"-n", "-t", c.DirectorIP}, args...)
	if c.CertPath != "" {
		args = append([]string{"--ca-cert", c.CertPath}, args...)
	}
	return args
}

func (c *BoshCommand) Run(command string) error {
	cmd := exec.Command("bosh", c.args(command)...)
	log.Printf("RUNNING %q\n", strings.Join(cmd.Args, " "))

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	if err != nil {
		return err
	}
	session.Wait(c.Timeout)

	exitCode := session.ExitCode()
	if exitCode != 0 {
		var stderr []byte
		if session.Err != nil {
			stderr = session.Err.Contents()
		}
		return fmt.Errorf("Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\n",
			strings.Join(cmd.Args, " "), exitCode, stderr)
	}
	return nil
}

var _ = Describe("BOSH Windows", func() {
	var (
		bosh           *BoshCommand
		deploymentName string
	)

	BeforeEach(func() {
		var certPath string

		cert := os.Getenv("BOSH_CA_CERT")
		if cert != "" {
			certFile, err := ioutil.TempFile("", "")
			Expect(err).To(BeNil())

			_, err = certFile.Write([]byte(cert))
			Expect(err).To(BeNil())

			certPath, err = filepath.Abs(certFile.Name())
			Expect(err).To(BeNil())
		}

		bosh = NewBoshCommand(os.Getenv("DIRECTOR_IP"), certPath)

		bosh.Run("login")
		deploymentName = fmt.Sprintf("windows-acceptance-test-%d", time.Now().UTC().Unix())
	})

	AfterEach(func() {
		if bosh.CertPath != "" {
			os.RemoveAll(bosh.CertPath)
		}
		bosh.Run(fmt.Sprintf("delete deployment %s --force", deploymentName))
	})

	AfterSuite(func() {
		bosh.Run("cleanup")
	})

	It("can run an errand", func() {
		manifest, err := generateManifest(deploymentName)
		Expect(err).To(BeNil())

		manifestFile, err := ioutil.TempFile("", "")
		Expect(err).To(BeNil())

		_, err = manifestFile.Write(manifest)
		Expect(err).To(BeNil())

		manifestPath, err := filepath.Abs(manifestFile.Name())
		Expect(err).To(BeNil())
		defer os.RemoveAll(manifestPath)

		err = bosh.Run("create release --name errand-release --force --timestamp-version --dir assets/errand-release")
		Expect(err).To(BeNil())

		err = bosh.Run("upload release --dir assets/errand-release")
		Expect(err).To(BeNil())

		stemcellPath := filepath.Join(
			os.Getenv("GOPATH"),
			os.Getenv("STEMCELL_PATH"),
		)

		matches, err := filepath.Glob(stemcellPath)
		Expect(err).To(BeNil())
		Expect(matches).To(HaveLen(1))

		err = bosh.Run(fmt.Sprintf("upload stemcell %s --skip-if-exists", matches[0]))
		Expect(err).To(BeNil())

		err = bosh.Run(fmt.Sprintf("-d %s deploy", manifestPath))
		Expect(err).To(BeNil())

		err = bosh.Run(fmt.Sprintf("-d %s run errand errand", manifestPath))
		Expect(err).To(BeNil())
	})
})
