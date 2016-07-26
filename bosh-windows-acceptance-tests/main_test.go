package bosh_windows_acceptance_tests_test

import (
	"bytes"
	"fmt"
	"html/template"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

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
  - name: default
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

func generateManifest() (string, error) {
	manifestProperties := ManifestProperties{
		DeploymentName: "foo",
		DirectorUUID:   os.Getenv("DIRECTOR_UUID"),
		ReleaseName:    "errand-release",
		StemcellName:   os.Getenv("STEMCELL_NAME"),
		JobName:        "errand",
	}
	templ, err := template.New("").Parse(manifestTemplate)
	if err != nil {
		return "", err
	}
	buf := bytes.NewBufferString("")
	err = templ.Execute(buf, manifestProperties)
	return buf.String(), err
}

var certPath string

func runBoshCommand(command string) error {
	args := strings.Split(command, " ")

	args = append([]string{"-n", "-t", os.Getenv("DIRECTOR_IP")}, args...)
	if certPath != "" {
		args = append([]string{"--ca-cert", certPath}, args...)
	}

	cmd := exec.Command("bosh", args...)
	fmt.Fprintf(GinkgoWriter, "RUNNING %q\n", strings.Join(cmd.Args, " "))
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	if err != nil {
		return err
	}
	session.Wait(15 * time.Minute)
	exitCode := session.ExitCode()
	if exitCode != 0 {
		return fmt.Errorf("Non-zero exit code for cmd %q: %d", strings.Join(cmd.Args, " "), exitCode)
	}
	return nil
}

var _ = Describe("BOSH Windows", func() {
	BeforeEach(func() {
		cert := os.Getenv("BOSH_CA_CERT")
		if cert != "" {
			certFile, err := ioutil.TempFile("", "")
			Expect(err).To(BeNil())
			_, err = certFile.Write([]byte(cert))
			Expect(err).To(BeNil())

			certPath, err = filepath.Abs(certFile.Name())
			Expect(err).To(BeNil())
		}

		runBoshCommand("login")
	})

	It("can run an errand", func() {
		manifest, err := generateManifest()
		Expect(err).To(BeNil())

		manifestFile, err := ioutil.TempFile("", "")
		Expect(err).To(BeNil())

		_, err = manifestFile.Write([]byte(manifest))
		Expect(err).To(BeNil())

		manifestPath, err := filepath.Abs(manifestFile.Name())
		Expect(err).To(BeNil())

		err = runBoshCommand("create release --name errand-release --force --timestamp-version --dir assets/errand-release")
		Expect(err).To(BeNil())

		err = runBoshCommand("upload release --dir assets/errand-release")
		Expect(err).To(BeNil())

		stemcellPath := os.Getenv("STEMCELL_PATH")
		matches, err := filepath.Glob(stemcellPath)
		Expect(err).To(BeNil())
		Expect(matches).To(HaveLen(1))

		err = runBoshCommand(fmt.Sprintf("upload stemcell %s --skip-if-exists", matches[0]))
		Expect(err).To(BeNil())
		err = runBoshCommand(fmt.Sprintf("-d %s deploy", manifestPath))
		Expect(err).To(BeNil())

		err = runBoshCommand(fmt.Sprintf("-d %s run errand errand", manifestPath))
		Expect(err).To(BeNil())
	})
})
