package bosh_windows_acceptance_tests_test

import (
	"bytes"
	"fmt"
	"html/template"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

func init() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.SetOutput(GinkgoWriter)
}

const BOSH_TIMEOUT = 45 * time.Minute
const GoZipFile = "go1.7.1.windows-amd64.zip"
const GolangURL = "https://storage.googleapis.com/golang/" + GoZipFile

var manifestTemplate = `
---
name: {{.DeploymentName}}
director_uuid: {{.DirectorUUID}}

releases:
- name: {{.ReleaseName}}
  version: latest

stemcells:
- alias: windows
  name: {{.StemcellName}}
  version: latest

update:
  canaries: 0
  canary_watch_time: 60000
  update_watch_time: 60000
  max_in_flight: 2

instance_groups:
- name: simple-job
  instances: 1
  stemcell: windows
  lifecycle: service
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: []
  networks:
  - name: {{.Network}}
  jobs:
  - name: simple-job
    release: {{.ReleaseName}}
- name: verify-autoupdates
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: []
  networks:
  - name: {{.Network}}
  jobs:
  - name: verify-autoupdates
    release: {{.ReleaseName}}
- name: check-system
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: []
  networks:
  - name: {{.Network}}
  jobs:
  jobs:
  - name: check-system
    release: {{.ReleaseName}}
`

type ManifestProperties struct {
	DeploymentName string
	DirectorUUID   string
	ReleaseName    string
	StemcellName   string
	AZ             string
	VmType         string
	Network        string
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
	az := os.Getenv("AZ")
	if az == "" {
		return nil, fmt.Errorf("invalid AZ: %q", az)
	}
	vmType := os.Getenv("VM_TYPE")
	if vmType == "" {
		return nil, fmt.Errorf("invalid VM_TYPE: %q", vmType)
	}
	network := os.Getenv("NETWORK")
	if network == "" {
		return nil, fmt.Errorf("invalid NETWORK: %q", network)
	}

	manifestProperties := ManifestProperties{
		DeploymentName: deploymentName,
		DirectorUUID:   uuid,
		ReleaseName:    "bwats-release",
		StemcellName:   stemcell,
		AZ:             az,
		VmType:         vmType,
		Network:        network,
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

func NewBoshCommand(DirectorIP, CertPath string, duration time.Duration) *BoshCommand {
	return &BoshCommand{
		DirectorIP: DirectorIP,
		CertPath:   CertPath,
		Timeout:    duration,
	}
}

func (c *BoshCommand) args(command string) []string {
	args := strings.Split(command, " ")
	args = append([]string{"-n", "-e", c.DirectorIP}, args...)
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
		stdout := session.Out.Contents()
		return fmt.Errorf("Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\nSTDOUT:%s\n",
			strings.Join(cmd.Args, " "), exitCode, stderr, stdout)
	}
	return nil
}

func downloadGo() (string, error) {
	dirname, err := ioutil.TempDir("", "")
	if err != nil {
		return "", err
	}

	path := filepath.Join(dirname, GoZipFile)
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0666)
	if err != nil {
		return "", err
	}
	defer f.Close()

	res, err := http.Get(GolangURL)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if _, err := io.Copy(f, res.Body); err != nil {
		return "", err
	}

	return path, nil
}

func downloadLogs(jobName string, index int) *gbytes.Buffer {
	tempDir, err := ioutil.TempDir("", "")
	Expect(err).To(Succeed())
	defer os.RemoveAll(tempDir)

	err = bosh.Run(fmt.Sprintf("-d %s logs %s/%d --dir %s", deploymentName, jobName, index, tempDir))
	Expect(err).To(Succeed())

	matches, err := filepath.Glob(filepath.Join(tempDir, fmt.Sprintf("%s.%s.%d-*.tgz", deploymentName, jobName, index)))
	Expect(err).To(Succeed())
	Expect(matches).To(HaveLen(1))

	cmd := exec.Command("tar", "xf", matches[0], "-O", fmt.Sprintf("./%s/%s/job-service-wrapper.out.log", jobName, jobName))
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).To(Succeed())

	return session.Wait().Out
}

var (
	bosh           *BoshCommand
	deploymentName string
	manifestPath   string
	boshCertPath   string
)

var _ = Describe("BOSH Windows", func() {

	BeforeSuite(func() {

		cert := os.Getenv("BOSH_CA_CERT")
		if cert != "" {
			certFile, err := ioutil.TempFile("", "")
			Expect(err).To(BeNil())

			_, err = certFile.Write([]byte(cert))
			Expect(err).To(BeNil())

			boshCertPath, err = filepath.Abs(certFile.Name())
			Expect(err).To(BeNil())
		}

		bosh = NewBoshCommand(os.Getenv("DIRECTOR_IP"), boshCertPath, BOSH_TIMEOUT)

		bosh.Run("login")
		deploymentName = fmt.Sprintf("windows-acceptance-test-%d", time.Now().UTC().Unix())

		pwd, err := os.Getwd()
		Expect(err).To(BeNil())
		Expect(os.Chdir(filepath.Join(pwd, "assets", "bwats-release"))).To(Succeed()) // push
		defer os.Chdir(pwd)                                                           // pop

		manifest, err := generateManifest(deploymentName)
		Expect(err).To(Succeed())

		manifestFile, err := ioutil.TempFile("", "")
		Expect(err).To(Succeed())

		_, err = manifestFile.Write(manifest)
		Expect(err).To(Succeed())

		manifestPath, err = filepath.Abs(manifestFile.Name())
		Expect(err).To(Succeed())

		goZipPath, err := downloadGo()
		Expect(err).To(Succeed())

		Expect(bosh.Run("add-blob " + goZipPath + " golang-windows/" + GoZipFile)).To(Succeed())

		Expect(bosh.Run("create-release --force --timestamp-version")).To(Succeed())

		Expect(bosh.Run("upload-release")).To(Succeed())

		stemcellPath := filepath.Join(
			os.Getenv("GOPATH"),
			os.Getenv("STEMCELL_PATH"),
		)

		matches, err := filepath.Glob(stemcellPath)
		Expect(err).To(Succeed())
		Expect(matches).To(HaveLen(1))

		err = bosh.Run(fmt.Sprintf("upload-stemcell %s", matches[0]))
		if err != nil {
			//AWS takes a while to distribute the AMI across accounts
			time.Sleep(2 * time.Minute)
		}
		Expect(err).To(Succeed())

		err = bosh.Run(fmt.Sprintf("-d %s deploy %s", deploymentName, manifestPath))
		Expect(err).To(Succeed())
	})

	AfterSuite(func() {
		bosh.Run(fmt.Sprintf("-d %s delete-deployment --force", deploymentName))

		bosh.Run("clean-up --all")
		if bosh.CertPath != "" {
			os.RemoveAll(bosh.CertPath)
		}
		if manifestPath != "" {
			os.RemoveAll(manifestPath)
		}
	})

	It("can run a job that relies on a package", func() {
		Eventually(downloadLogs("simple-job", 0),
			time.Second*60).Should(gbytes.Say("60 seconds passed"))
	})

	It("successfully runs redeploy in a tight loop", func() {
		const redeployRetries = 10

		pwd, err := os.Getwd()
		Expect(err).To(BeNil())
		Expect(os.Chdir(filepath.Join(pwd, "assets", "bwats-release"))).To(Succeed()) // push
		defer os.Chdir(pwd)                                                           // pop

		pwd, err = os.Getwd()
		Expect(err).To(BeNil())
		f, err := os.OpenFile(filepath.Join(pwd, "jobs", "simple-job", "templates", "pre-start.ps1"),
			os.O_APPEND|os.O_WRONLY, 0600)
		Expect(err).To(BeNil())
		defer f.Close()

		for i := 0; i < redeployRetries; i++ {
			_, err = f.WriteString(fmt.Sprintf("Write-Host \"Redeploy attempt #%d\"", i))
			Expect(err).To(Succeed())

			Expect(bosh.Run("create-release --force --timestamp-version")).To(Succeed())

			Expect(bosh.Run("upload-release")).To(Succeed())

			err = bosh.Run(fmt.Sprintf("-d %s deploy %s", deploymentName, manifestPath))
			if err != nil {
				downloadLogs("simple-job", 0)
				Fail(err.Error())
			}
		}
	})

	It("has Auto Update turned off", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand verify-autoupdates --tty", deploymentName))
		Expect(err).To(Succeed())
	})

	It("checks system dependencies and security", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand --download-logs check-system --tty", deploymentName))
		Expect(err).To(Succeed())
	})

})
