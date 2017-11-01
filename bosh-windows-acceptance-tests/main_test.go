package bosh_windows_acceptance_tests_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
	"gopkg.in/yaml.v2"
)

func init() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.SetOutput(GinkgoWriter)
}

const BOSH_TIMEOUT = 45 * time.Minute
const GoZipFile = "go1.7.1.windows-amd64.zip"
const GolangURL = "https://storage.googleapis.com/golang/" + GoZipFile
const redeployRetries = 10

var manifestTemplate = `
---
name: {{.DeploymentName}}

releases:
- name: {{.ReleaseName}}
  version: '{{.ReleaseVersion}}'

stemcells:
- alias: windows
  os: {{.StemcellOs}}
  version: '{{.StemcellVersion}}'

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
  vm_extensions: [{{.VmExtensions}}]
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
  vm_extensions: [{{.VmExtensions}}]
  networks:
  - name: {{.Network}}
  jobs:
  - name: verify-autoupdates
    release: {{.ReleaseName}}
- name: verify-agent-start-type
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: [{{.VmExtensions}}]
  networks:
  - name: {{.Network}}
  jobs:
  - name: verify-agent-start-type
    release: {{.ReleaseName}}
- name: check-system
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: [{{.VmExtensions}}]
  networks:
  - name: {{.Network}}
  jobs:
  - name: check-system
    release: {{.ReleaseName}}
- name: verify-updated
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: [{{.VmExtensions}}]
  networks:
  - name: {{.Network}}
  jobs:
  - name: verify-updated
    release: {{.ReleaseName}}
- name: verify-randomize-password
  instances: 1
  stemcell: windows
  lifecycle: errand
  azs: [{{.AZ}}]
  vm_type: {{.VmType}}
  vm_extensions: [{{.VmExtensions}}]
  networks:
  - name: {{.Network}}
  jobs:
  - name: verify-randomize-password
    release: {{.ReleaseName}}
`

type ManifestProperties struct {
	DeploymentName  string
	ReleaseName     string
	AZ              string
	VmType          string
	VmExtensions    string
	Network         string
	StemcellOs      string
	StemcellVersion string
	ReleaseVersion  string
}

type StemcellInfo struct {
	Version string `yaml:"version"`
	Name    string `yaml:"name"`
}

type BoshStemcell struct {
	Tables []struct {
		Rows []struct {
			Version string `json:"version"`
		} `json:"Rows"`
	} `json:"Tables"`
}

type Config struct {
	Bosh struct {
		CaCert       string `json:"ca_cert"`
		Client       string `json:"client"`
		ClientSecret string `json:"client_secret"`
		Target       string `json:"target"`
	} `json:"bosh"`
	Stemcellpath string `json:"stemcell_path"`
	StemcellOs   string `json:"stemcell_os"`
	Az           string `json:"az"`
	VmType       string `json:"vm_type"`
	VmExtensions string `json:"vm_extensions"`
	Network      string `json:"network"`
	SkipCleanup  bool   `json:"skip_cleanup"`
}

func NewConfig() (*Config, error) {
	configFilePath := os.Getenv("CONFIG_JSON")
	if configFilePath == "" {
		return nil, fmt.Errorf("invalid config file path: %v", configFilePath)
	}
	body, err := ioutil.ReadFile(configFilePath)
	if err != nil {
		return nil, fmt.Errorf("empty config file path: %v", configFilePath)
	}
	var config Config
	err = json.Unmarshal(body, &config)
	if err != nil {
		return nil, fmt.Errorf("unable to parse config file: %v", body)
	}
	if config.StemcellOs == "" {
		return nil, fmt.Errorf("missing required field: %v", "stemcell_os")
	}
	return &config, nil
}

func (c *Config) generateManifest(deploymentName string, stemcellVersion string, bwatsVersion string) ([]byte, error) {
	manifestProperties := ManifestProperties{
		DeploymentName:  deploymentName,
		ReleaseName:     "bwats-release",
		AZ:              c.Az,
		VmType:          c.VmType,
		VmExtensions:    c.VmExtensions,
		Network:         c.Network,
		StemcellOs:      c.StemcellOs,
		StemcellVersion: stemcellVersion,
		ReleaseVersion:  bwatsVersion,
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
	DirectorIP   string
	Client       string
	ClientSecret string
	CertPath     string // Path to CA CERT file, if any
	Timeout      time.Duration
}

func NewBoshCommand(config *Config, CertPath string, duration time.Duration) *BoshCommand {
	return &BoshCommand{
		DirectorIP:   config.Bosh.Target,
		Client:       config.Bosh.Client,
		ClientSecret: config.Bosh.ClientSecret,
		CertPath:     CertPath,
		Timeout:      duration,
	}
}

func (c *BoshCommand) args(command string) []string {
	args := strings.Split(command, " ")
	args = append([]string{"-n", "-e", c.DirectorIP, "--client", c.Client, "--client-secret", c.ClientSecret}, args...)
	if c.CertPath != "" {
		args = append([]string{"--ca-cert", c.CertPath}, args...)
	}
	return args
}

func (c *BoshCommand) Run(command string) error {
	return c.RunIn(command, "")
}

func (c *BoshCommand) RunInStdOut(command, dir string) ([]byte, error) {
	cmd := exec.Command("bosh", c.args(command)...)
	if dir != "" {
		cmd.Dir = dir
		log.Printf("\nRUNNING %q IN %q\n", strings.Join(cmd.Args, " "), dir)
	} else {
		log.Printf("\nRUNNING %q\n", strings.Join(cmd.Args, " "))
	}

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	if err != nil {
		return nil, err
	}
	session.Wait(c.Timeout)

	exitCode := session.ExitCode()
	stdout := session.Out.Contents()
	if exitCode != 0 {
		var stderr []byte
		if session.Err != nil {
			stderr = session.Err.Contents()
		}
		return stdout, fmt.Errorf("Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\nSTDOUT:%s\n",
			strings.Join(cmd.Args, " "), exitCode, stderr, stdout)
	}
	return stdout, nil
}

func (c *BoshCommand) RunIn(command, dir string) error {
	_, err := c.RunInStdOut(command, dir)
	return err
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

func fetchStemcellInfo(stemcellPath string) (StemcellInfo, error) {
	var stemcellInfo StemcellInfo
	tempDir, err := ioutil.TempDir("", "")
	Expect(err).To(Succeed())
	defer os.RemoveAll(tempDir)

	cmd := exec.Command("tar", "xf", stemcellPath, "-C", tempDir, "stemcell.MF")
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).To(Succeed())
	session.Wait(20 * time.Minute)

	exitCode := session.ExitCode()
	if exitCode != 0 {
		var stderr []byte
		if session.Err != nil {
			stderr = session.Err.Contents()
		}
		stdout := session.Out.Contents()
		return stemcellInfo, fmt.Errorf("Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\nSTDOUT:%s\n",
			strings.Join(cmd.Args, " "), exitCode, stderr, stdout)
	}

	stemcellMF, err := ioutil.ReadFile(fmt.Sprintf("%s/%s", tempDir, "stemcell.MF"))
	Expect(err).To(Succeed())

	err = yaml.Unmarshal(stemcellMF, &stemcellInfo)
	Expect(err).To(Succeed())
	Expect(stemcellInfo.Version).ToNot(BeNil())
	Expect(stemcellInfo.Version).ToNot(BeEmpty())

	return stemcellInfo, nil
}

func getTimestampInMs() int64 {
	return time.Now().UTC().UnixNano() / int64(time.Millisecond)
}

var (
	bosh                      *BoshCommand
	deploymentName            string
	manifestPath              string
	boshCertPath              string
	stemcellName              string
	stemcellVersion           string
	releaseVersion            string
	tightLoopStemcellVersions [redeployRetries]string
)

var _ = Describe("BOSH Windows", func() {
	var config *Config

	BeforeSuite(func() {
		var err error
		config, err = NewConfig()
		Expect(err).To(Succeed())

		cert := config.Bosh.CaCert
		if cert != "" {
			certFile, err := ioutil.TempFile("", "")
			Expect(err).To(Succeed())

			_, err = certFile.Write([]byte(cert))
			Expect(err).To(Succeed())

			boshCertPath, err = filepath.Abs(certFile.Name())
			Expect(err).To(Succeed())
		}

		timeout := BOSH_TIMEOUT
		if s := os.Getenv("BWATS_BOSH_TIMEOUT"); s != "" {
			d, err := time.ParseDuration(s)
			if err != nil {
				log.Printf("Error parsing BWATS_BOSH_TIMEOUT (%s): %s - falling back to default\n", s, err)
			} else {
				log.Printf("Using BWATS_BOSH_TIMEOUT (%s) as timeout\n", s)
				timeout = d
			}
		}
		log.Printf("Using timeout (%s) for BOSH commands\n", timeout)

		bosh = NewBoshCommand(config, boshCertPath, timeout)

		bosh.Run("login")
		deploymentName = fmt.Sprintf("windows-acceptance-test-%d", getTimestampInMs())

		pwd, err := os.Getwd()
		Expect(err).To(Succeed())
		releaseDir := filepath.Join(pwd, "assets", "bwats-release")

		var stemcellInfo StemcellInfo
		stemcellInfo, err = fetchStemcellInfo(config.Stemcellpath)
		Expect(err).To(Succeed())

		stemcellVersion = stemcellInfo.Version
		stemcellName = stemcellInfo.Name

		// get the output of bosh stemcells
		var stdout []byte
		stdout, err = bosh.RunInStdOut("stemcells --json", "")
		Expect(err).To(Succeed())

		// Ensure stemcell version has not already been uploaded to bosh director
		var stdoutInfo BoshStemcell
		json.Unmarshal(stdout, &stdoutInfo)
		for _, row := range stdoutInfo.Tables[0].Rows {
			Expect(row.Version).NotTo(ContainSubstring(stemcellVersion))
		}

		// Generate BWATS release version
		releaseVersion = fmt.Sprintf("0.dev+%d", getTimestampInMs())

		manifest, err := config.generateManifest(deploymentName, stemcellVersion, releaseVersion)
		Expect(err).To(Succeed())

		manifestFile, err := ioutil.TempFile("", "")
		Expect(err).To(Succeed())

		_, err = manifestFile.Write(manifest)
		Expect(err).To(Succeed())

		manifestPath, err = filepath.Abs(manifestFile.Name())
		Expect(err).To(Succeed())

		goZipPath, err := downloadGo()
		Expect(err).To(Succeed())

		Expect(bosh.RunIn("add-blob "+goZipPath+" golang-windows/"+GoZipFile, releaseDir)).To(Succeed())

		Expect(bosh.RunIn("create-release --force --version "+releaseVersion, releaseDir)).To(Succeed())

		Expect(bosh.RunIn("upload-release", releaseDir)).To(Succeed())

		matches, err := filepath.Glob(config.Stemcellpath)
		Expect(err).To(Succeed())
		Expect(matches).To(HaveLen(1))

		err = bosh.Run(fmt.Sprintf("upload-stemcell %s", matches[0]))
		if err != nil {
			// AWS takes a while to distribute the AMI across accounts
			time.Sleep(2 * time.Minute)
		}
		Expect(err).To(Succeed())

		err = bosh.Run(fmt.Sprintf("-d %s deploy %s", deploymentName, manifestPath))
		Expect(err).To(Succeed())
	})

	AfterSuite(func() {
		if config.SkipCleanup {
			return
		}

		bosh.Run(fmt.Sprintf("-d %s delete-deployment --force", deploymentName))
		bosh.Run(fmt.Sprintf("delete-stemcell %s/%s", stemcellName, stemcellVersion))
		bosh.Run(fmt.Sprintf("delete-release bwats-release/%s", releaseVersion))

		// Delete the releases created by the tight loop test
		for _, version := range tightLoopStemcellVersions {
			bosh.Run(fmt.Sprintf("delete-release bwats-release/%s", version))
		}

		if bosh.CertPath != "" {
			os.RemoveAll(bosh.CertPath)
		}
		if manifestPath != "" {
			os.RemoveAll(manifestPath)
		}
	})

	It("can run a job that relies on a package", func() {
		time.Sleep(60 * time.Second)
		Eventually(downloadLogs("simple-job", 0),
			time.Second*65).Should(gbytes.Say("60 seconds passed"))
	})

	It("successfully runs redeploy in a tight loop", func() {

		pwd, err := os.Getwd()
		Expect(err).To(BeNil())
		releaseDir := filepath.Join(pwd, "assets", "bwats-release")

		f, err := os.OpenFile(filepath.Join(releaseDir, "jobs", "simple-job", "templates", "pre-start.ps1"),
			os.O_APPEND|os.O_WRONLY, 0600)
		Expect(err).ToNot(HaveOccurred())
		defer f.Close()

		for i := 0; i < redeployRetries; i++ {
			log.Printf("Redeploy attempt: #%d\n", i)

			version := fmt.Sprintf("0.dev+%d", getTimestampInMs())
			tightLoopStemcellVersions[i] = version
			Expect(bosh.RunIn("create-release --force --version "+version, releaseDir)).To(Succeed())

			Expect(bosh.RunIn("upload-release", releaseDir)).To(Succeed())

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

	// The Agent changes the start type of it's service wrapper to 'Manual' immediately
	// before the first job is started - this is prevent the Agent from coming back up
	// after a restart, which we don't support.
	//
	// Since the Agent will have changed it's start type by the time that this errand
	// runs we check for the presence of a registry key that is an artifact of the
	// original 'Automatic (Delayed Start)' configuration.
	It("currently has a Service StartType of 'Manual' and initially had a StartType of 'Delayed'", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand verify-agent-start-type --tty", deploymentName))
		Expect(err).To(Succeed())
	})

	It("checks system dependencies and security", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand --download-logs check-system --tty", deploymentName))
		Expect(err).To(Succeed())
	})

	It("randomizes admin password", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand --download-logs verify-randomize-password --tty", deploymentName))
		Expect(err).To(Succeed())
	})

	PIt("Is fully updated", func() {
		err := bosh.Run(fmt.Sprintf("-d %s run-errand --download-logs verify-updated --tty", deploymentName))
		Expect(err).To(Succeed())
	})

})
