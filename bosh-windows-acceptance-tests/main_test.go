package bosh_windows_acceptance_tests_test

import (
	"archive/zip"
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
	"time"

	"bytes"

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

const BOSH_TIMEOUT = 90 * time.Minute

const GoZipFile = "go1.12.7.windows-amd64.zip"
const GolangURL = "https://storage.googleapis.com/golang/" + GoZipFile
const LgpoUrl = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
const lgpoFile = "LGPO.exe"
const redeployRetries = 10

type ManifestProperties struct {
	DeploymentName            string
	ReleaseName               string
	AZ                        string
	VmType                    string
	RootEphemeralVmType       string
	VmExtensions              string
	Network                   string
	StemcellOs                string
	StemcellVersion           string
	ReleaseVersion            string
	DefaultUsername           string
	DefaultPassword           string
	MountEphemeralDisk        bool
	SSHDisabledByDefault      bool
	SecurityComplianceApplied bool
}

type StemcellYML struct {
	Version string `yaml:"version"`
	Name    string `yaml:"name"`
}

type Config struct {
	Bosh struct {
		CaCert       string `json:"ca_cert"`
		Client       string `json:"client"`
		ClientSecret string `json:"client_secret"`
		Target       string `json:"target"`
	} `json:"bosh"`
	Stemcellpath              string `json:"stemcell_path"`
	StemcellOs                string `json:"stemcell_os"`
	Az                        string `json:"az"`
	VmType                    string `json:"vm_type"`
	RootEphemeralVmType       string `json:"root_ephemeral_vm_type"`
	VmExtensions              string `json:"vm_extensions"`
	Network                   string `json:"network"`
	DefaultUsername           string `json:"default_username"`
	DefaultPassword           string `json:"default_password"`
	SkipCleanup               bool   `json:"skip_cleanup"`
	MountEphemeralDisk        bool   `json:"mount_ephemeral_disk"`
	SkipMSUpdateTest          bool   `json:"skip_ms_update_test"`
	SSHDisabledByDefault      bool   `json:"ssh_disabled_by_default"`
	SecurityComplianceApplied bool   `json:"security_compliance_applied"`
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
		return nil, fmt.Errorf("unable to parse config file: %s: %s", err.Error(), string(body))
	}
	if config.StemcellOs == "" {
		return nil, fmt.Errorf("missing required field: %v", "stemcell_os")
	}

	if config.VmExtensions == "" {
		config.VmExtensions = "500GB_ephemeral_disk"
	}

	return &config, nil
}

type BoshCommand struct {
	DirectorIP   string
	Client       string
	ClientSecret string
	CertPath     string // Path to CA CERT file, if any
	Timeout      time.Duration
}

func setupBosh(config *Config) *BoshCommand {
	var boshCertPath string
	cert := config.Bosh.CaCert
	if cert != "" {
		certFile, err := ioutil.TempFile("", "")
		Expect(err).NotTo(HaveOccurred())

		_, err = certFile.Write([]byte(cert))
		Expect(err).NotTo(HaveOccurred())

		boshCertPath, err = filepath.Abs(certFile.Name())
		Expect(err).NotTo(HaveOccurred())
	}

	timeout := BOSH_TIMEOUT
	var err error
	if s := os.Getenv("BWATS_BOSH_TIMEOUT"); s != "" {
		timeout, err = time.ParseDuration(s)
		log.Printf("Using BWATS_BOSH_TIMEOUT (%s) as timeout\n", s)

		if err != nil {
			log.Printf("Error parsing BWATS_BOSH_TIMEOUT (%s): %s - falling back to default\n", s, err)
		}
	}

	return &BoshCommand{
		DirectorIP:   config.Bosh.Target,
		Client:       config.Bosh.Client,
		ClientSecret: config.Bosh.ClientSecret,
		CertPath:     boshCertPath,
		Timeout:      timeout,
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
	Eventually(session, c.Timeout).Should(gexec.Exit())

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

var (
	bosh                      *BoshCommand
	deploymentName            string
	manifestPath              string
	stemcellName              string
	stemcellVersion           string
	releaseVersion            string
	tightLoopStemcellVersions []string
	config                    *Config
)

var _ = Describe("BOSH Windows", func() {
	BeforeSuite(func() {
		var err error

		config, err = NewConfig()
		Expect(err).NotTo(HaveOccurred())
		bosh = setupBosh(config)

		bosh.Run("login")
		deploymentName = fmt.Sprintf("windows-acceptance-test-%d", getTimestampInMs())

		stemcellYML, err := fetchStemcellInfo(config.Stemcellpath)
		Expect(err).NotTo(HaveOccurred())

		stemcellName = stemcellYML.Name
		stemcellVersion = stemcellYML.Version

		releaseVersion = createBwatsRelease(bosh)

		uploadStemcell(config, bosh)

		err = config.deploy(bosh, deploymentName, stemcellVersion, releaseVersion)
		Expect(err).NotTo(HaveOccurred())
	})

	AfterSuite(func() {
		// Delete the releases created by the tight loop test
		for index, version := range tightLoopStemcellVersions {
			if index == len(tightLoopStemcellVersions)-1 {
				continue // Last release is still being used by the deployment, so it cannot be deleted yet
			}
			bosh.Run(fmt.Sprintf("delete-release bwats-release/%s", version))
		}
		if config.SkipCleanup {
			return
		}

		bosh.Run(fmt.Sprintf("-d %s delete-deployment --force", deploymentName))
		bosh.Run(fmt.Sprintf("delete-stemcell %s/%s", stemcellName, stemcellVersion))
		bosh.Run(fmt.Sprintf("delete-release bwats-release/%s", releaseVersion))
		if len(tightLoopStemcellVersions) != 0 {
			bosh.Run(fmt.Sprintf("delete-release bwats-release/%s", tightLoopStemcellVersions[len(tightLoopStemcellVersions)-1]))
		}

		if bosh.CertPath != "" {
			os.RemoveAll(bosh.CertPath)
		}
	})

	It("can run a job that relies on a package", func() {
		time.Sleep(60 * time.Second)
		Eventually(downloadLogs("check-multiple", "simple-job", 0, bosh),
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
			tightLoopStemcellVersions = append(tightLoopStemcellVersions, version)
			Expect(bosh.RunIn("create-release --force --version "+version, releaseDir)).To(Succeed())

			Expect(bosh.RunIn("upload-release", releaseDir)).To(Succeed())

			err = config.deploy(bosh, deploymentName, stemcellVersion, version)

			if err != nil {
				downloadLogs("check-multiple", "simple-job", 0, bosh)
				Fail(err.Error())
			}
		}
	})

	It("checks system dependencies and security, auto update has turned off, currently has a Service StartType of 'Manual' and initially had a StartType of 'Delayed', and password is randomized", func() {
		err := runTest("check-system")
		Expect(err).NotTo(HaveOccurred())
	})

	It("is fully updated", func() { // 860s
		if config.SkipMSUpdateTest {
			Skip("Skipping check-updates test - SkipMSUpdateTest set to true")
		} else {
			err := runTest("check-updates")
			Expect(err).NotTo(HaveOccurred())
		}
	})

	It("has all certificate authority certs that are present on the Windows Update Server", func() {
		err := runTest("check-wu-certs")
		Expect(err).NotTo(HaveOccurred())
	})

	It("mounts ephemeral disks when asked to do so and does not mount them otherwise", func() {
		err := runTest("ephemeral-disk")
		Expect(err).NotTo(HaveOccurred())
	})

	Context("slow compiling go package", func() {
		var slowCompilingDeploymentName string

		AfterEach(func() {
			bosh.Run(fmt.Sprintf("-d %s delete-deployment --force", slowCompilingDeploymentName))
		})

		It("deploys when there is a slow to compile go package", func() {
			pwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())
			manifestPath = filepath.Join(pwd, "assets", "slow-compile-manifest.yml")

			slowCompilingDeploymentName = fmt.Sprintf("windows-acceptance-test-slow-compile-%d", getTimestampInMs())

			config.deployWithManifest(bosh, slowCompilingDeploymentName, stemcellVersion, releaseVersion, manifestPath)
		})
	})

	Context("ssh enabled", func() {
		It("allows SSH connection", func() {
			err := bosh.Run(fmt.Sprintf("-d %s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())
		})

		It("cleans up ssh users after a successful connection", func() {
			err := bosh.Run(fmt.Sprintf("-d %s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())

			err = runTest("check-ssh") // test for C:\Users only having one ssh user, net users only containing one ssh user.
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
