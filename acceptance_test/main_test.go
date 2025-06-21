package windows_stemcell_acceptance_test

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
	"gopkg.in/yaml.v2"
)

const BoshTimeout = 90 * time.Minute

const GoZipFile = "go1.12.7.windows-amd64.zip"
const GolangURL = "https://storage.googleapis.com/golang/" + GoZipFile
const LgpoUrl = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
const lgpoFile = "LGPO.exe"
const redeployRetries = 10

var (
	boshCommand               *BoshCommand
	deploymentName            string
	manifestPath              string
	stemcellName              string
	stemcellVersion           string
	releaseVersion            string
	tightLoopStemcellVersions []string
	testConfig                *TestConfig
)

var _ = BeforeSuite(func() {
	configFilePath := os.Getenv("CONFIG_JSON")
	Expect(configFilePath).ToNot(BeEmpty(), fmt.Sprintf("invalid testConfig file path: '%s'", configFilePath))

	body, err := os.ReadFile(configFilePath)
	By(fmt.Sprintf("ReadFile:  '%s'\n%s", configFilePath, string(body)))
	Expect(err).NotTo(HaveOccurred(), fmt.Sprintf("empty testConfig file path: '%s'", configFilePath))

	err = json.Unmarshal(body, &testConfig)
	Expect(err).NotTo(HaveOccurred(), fmt.Sprintf("unable to parse testConfig file '%s', %v:", string(body), err))

	Expect(testConfig.StemcellOs).ToNot(BeEmpty(), fmt.Sprintf("missing required field: '%s'", "stemcell_os"))

	if testConfig.VmExtensions == "" {
		testConfig.VmExtensions = "500GB_ephemeral_disk"
	}

	boshCommand = newBoshCommand(testConfig)

	err = boshCommand.Run("login")
	Expect(err).NotTo(HaveOccurred())
	deploymentName = fmt.Sprintf("windows-acceptance-test-%d", getTimestampInMs())

	stemcellYML, err := fetchStemcellInfo(testConfig.StemcellPath)
	Expect(err).NotTo(HaveOccurred())

	stemcellName = stemcellYML.Name
	stemcellVersion = stemcellYML.Version

	releaseVersion = createBwatsRelease(boshCommand)

	uploadStemcell(testConfig, boshCommand)

	err = testConfig.deploy(boshCommand, deploymentName, stemcellVersion, releaseVersion)
	Expect(err).NotTo(HaveOccurred())
})

var _ = AfterSuite(func() {
	// Delete the releases created by the tight loop test
	for index, version := range tightLoopStemcellVersions {
		if index == len(tightLoopStemcellVersions)-1 {
			continue // Last release is still being used by the deployment, so it cannot be deleted yet
		}
		err := boshCommand.Run(fmt.Sprintf("delete-release bwats-release/%s", version))
		Expect(err).NotTo(HaveOccurred())
	}
	if testConfig.SkipCleanup {
		return
	}

	err := boshCommand.Run(fmt.Sprintf("-d %s delete-deployment --force", deploymentName))
	Expect(err).NotTo(HaveOccurred())
	err = boshCommand.Run(fmt.Sprintf("delete-stemcell %s/%s", stemcellName, stemcellVersion))
	Expect(err).NotTo(HaveOccurred())
	err = boshCommand.Run(fmt.Sprintf("delete-release bwats-release/%s", releaseVersion))
	Expect(err).NotTo(HaveOccurred())
	if len(tightLoopStemcellVersions) != 0 {
		err = boshCommand.Run(fmt.Sprintf("delete-release bwats-release/%s", tightLoopStemcellVersions[len(tightLoopStemcellVersions)-1]))
		Expect(err).NotTo(HaveOccurred())
	}

	if boshCommand.CertPath != "" {
		Expect(os.RemoveAll(boshCommand.CertPath)).To(Succeed())
	}
})

var _ = Describe("BOSH Windows", func() {
	It("can run a job that relies on a package", func() {
		time.Sleep(60 * time.Second)
		Eventually(downloadLogs("check-multiple", "simple-job", 0, boshCommand),
			time.Second*65).Should(gbytes.Say("60 seconds passed"))
	})

	It("successfully runs redeploy in a tight loop", func() {
		pwd, err := os.Getwd()
		Expect(err).To(BeNil())
		releaseDir := filepath.Join(pwd, "assets", "bwats-release")

		f, err := os.OpenFile(filepath.Join(releaseDir, "jobs", "simple-job", "templates", "pre-start.ps1"),
			os.O_APPEND|os.O_WRONLY, 0600)
		Expect(err).ToNot(HaveOccurred())
		defer f.Close() //nolint:errcheck

		for i := 0; i < redeployRetries; i++ {
			GinkgoWriter.Printf("Redeploy attempt: #%d\n", i)

			version := fmt.Sprintf("0.dev+%d", getTimestampInMs())
			tightLoopStemcellVersions = append(tightLoopStemcellVersions, version)
			Expect(boshCommand.RunIn(fmt.Sprintf("create-release --force --version %s", version), releaseDir)).To(Succeed())

			Expect(boshCommand.RunIn("upload-release", releaseDir)).To(Succeed())

			err = testConfig.deploy(boshCommand, deploymentName, stemcellVersion, version)

			if err != nil {
				downloadLogs("check-multiple", "simple-job", 0, boshCommand)
				Fail(err.Error())
			}
		}
	})

	It("checks system dependencies and security, auto update has turned off, currently has a Service StartType of 'Manual' and initially had a StartType of 'Delayed', and password is randomized", func() {
		err := boshCommand.RunErrand("check-system", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	It("is fully updated", func() { // 860s
		if testConfig.SkipMSUpdateTest {
			Skip("Skipping check-updates test - SkipMSUpdateTest set to true")
		} else {
			err := boshCommand.RunErrand("check-updates", deploymentName)
			Expect(err).NotTo(HaveOccurred())
		}
	})

	It("has all certificate authority certs that are present on the Windows Update Server", func() {
		err := boshCommand.RunErrand("check-wu-certs", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	It("mounts ephemeral disks when asked to do so and does not mount them otherwise", func() {
		err := boshCommand.RunErrand("ephemeral-disk", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	Context("slow compiling go package", func() {
		var slowCompilingDeploymentName string

		AfterEach(func() {
			err := boshCommand.Run(fmt.Sprintf("-d %s delete-deployment --force", slowCompilingDeploymentName))
			Expect(err).NotTo(HaveOccurred())
		})

		It("deploys when there is a slow to compile go package", func() {
			pwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())
			manifestPath = filepath.Join(pwd, "assets", "slow-compile-manifest.yml")

			slowCompilingDeploymentName = fmt.Sprintf("windows-acceptance-test-slow-compile-%d", getTimestampInMs())

			err = testConfig.deployWithManifest(boshCommand, slowCompilingDeploymentName, stemcellVersion, releaseVersion, manifestPath)
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Context("ssh enabled", func() {
		It("allows SSH connection", func() {
			err := boshCommand.Run(fmt.Sprintf("-d %s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())
		})

		It("cleans up ssh users after a successful connection", func() {
			err := boshCommand.Run(fmt.Sprintf("-d %s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())

			err = boshCommand.RunErrand("check-ssh", deploymentName) // test for C:\Users only having one ssh user, net users only containing one ssh user.
			Expect(err).NotTo(HaveOccurred())
		})
	})
})

type TestConfig struct {
	Bosh struct {
		CaCert       string `json:"ca_cert"`
		Client       string `json:"client"`
		ClientSecret string `json:"client_secret"`
		Target       string `json:"target"`
	} `json:"bosh"`
	StemcellPath              string `json:"stemcell_path"`
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

func getTimestampInMs() int64 {
	return time.Now().UTC().UnixNano() / int64(time.Millisecond)
}

type StemcellYML struct {
	Version string `yaml:"version"`
	Name    string `yaml:"name"`
}

func fetchStemcellInfo(stemcellPath string) (StemcellYML, error) {
	var stemcellInfo StemcellYML
	tempDir, err := os.MkdirTemp("", "")
	Expect(err).NotTo(HaveOccurred())
	defer os.RemoveAll(tempDir) //nolint:errcheck

	cmd := exec.Command("tar", "xf", stemcellPath, "-C", tempDir, "stemcell.MF")
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())
	Eventually(session, 20*time.Minute).Should(gexec.Exit())

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

	stemcellMF, err := os.ReadFile(fmt.Sprintf("%s/%s", tempDir, "stemcell.MF"))
	Expect(err).NotTo(HaveOccurred())

	err = yaml.Unmarshal(stemcellMF, &stemcellInfo)
	Expect(err).NotTo(HaveOccurred())
	Expect(stemcellInfo.Version).ToNot(BeNil())
	Expect(stemcellInfo.Version).ToNot(BeEmpty())

	return stemcellInfo, nil
}

type BoshCommand struct {
	DirectorIP   string
	Client       string
	ClientSecret string
	CertPath     string // Path to CA CERT file, if any
	Timeout      time.Duration
}

func newBoshCommand(config *TestConfig) *BoshCommand {
	var boshCertPath string
	cert := config.Bosh.CaCert
	if cert != "" {
		certFile, err := os.CreateTemp("", "")
		Expect(err).NotTo(HaveOccurred())

		_, err = certFile.Write([]byte(cert))
		Expect(err).NotTo(HaveOccurred())

		boshCertPath, err = filepath.Abs(certFile.Name())
		Expect(err).NotTo(HaveOccurred())
	}

	timeout := BoshTimeout
	var err error
	if s := os.Getenv("BWATS_BOSH_TIMEOUT"); s != "" {
		timeout, err = time.ParseDuration(s)
		GinkgoWriter.Printf("Using BWATS_BOSH_TIMEOUT (%s) as timeout\n", s)

		if err != nil {
			GinkgoWriter.Printf("Error parsing BWATS_BOSH_TIMEOUT (%s): %s - falling back to default\n", s, err)
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

func (c *BoshCommand) RunErrand(errandName string, deploymentName string) error {
	return c.Run(fmt.Sprintf("-d %s run-errand --download-logs %s --tty", deploymentName, errandName))
}

func (c *BoshCommand) RunInStdOut(command, dir string) ([]byte, error) {
	cmd := exec.Command("bosh", c.args(command)...)

	if dir != "" {
		cmd.Dir = dir
		GinkgoWriter.Printf("\nRUNNING %q IN %q\n", strings.Join(cmd.Args, " "), dir)
	} else {
		GinkgoWriter.Printf("\nRUNNING %q\n", strings.Join(cmd.Args, " "))
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
		return stdout,
			fmt.Errorf(
				"Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\nSTDOUT:%s\n",
				strings.Join(cmd.Args, " "), exitCode, stderr, stdout,
			)
	}
	return stdout, nil
}

func (c *BoshCommand) RunIn(command, dir string) error {
	_, err := c.RunInStdOut(command, dir)
	return err
}

func uploadStemcell(config *TestConfig, bosh *BoshCommand) {
	matches, err := filepath.Glob(config.StemcellPath)
	Expect(err).NotTo(HaveOccurred())
	Expect(matches).To(HaveLen(1))

	for {
		// the ami may not be immediately available, so we retry every three minutes.
		// if it is actually broken, the concourse timeout will kick in at 90 minutes.
		err = bosh.Run(fmt.Sprintf("upload-stemcell %s", matches[0]))
		if err != nil {
			time.Sleep(3 * time.Minute)
		} else {
			break
		}
	}

	Expect(err).NotTo(HaveOccurred())
}

func createBwatsRelease(bosh *BoshCommand) string {
	pwd, err := os.Getwd()
	Expect(err).NotTo(HaveOccurred())

	releaseVersion = fmt.Sprintf("0.dev+%d", getTimestampInMs())
	var goZipPath string
	if _, err = os.Stat(filepath.Join(pwd, GoZipFile)); os.IsNotExist(err) {
		goZipPath, err = downloadFile("golang-", GolangURL)
		Expect(err).NotTo(HaveOccurred())
	} else {
		goZipPath = filepath.Join(pwd, GoZipFile)
	}
	releaseDir := filepath.Join(pwd, "assets", "bwats-release")
	Expect(bosh.RunIn(fmt.Sprintf("add-blob %s golang-windows/%s", goZipPath, GoZipFile), releaseDir)).To(Succeed())

	var lgpoZipPath string
	if _, err = os.Stat(filepath.Join(pwd, "LGPO.zip")); os.IsNotExist(err) {
		lgpoZipPath, err = downloadFile("lgpo-", LgpoUrl)
		Expect(err).NotTo(HaveOccurred())
	} else {
		lgpoZipPath = filepath.Join(pwd, "LGPO.zip")
	}

	zipReader, err := zip.OpenReader(lgpoZipPath)
	Expect(err).NotTo(HaveOccurred())

	lgpoPath, err := os.CreateTemp("", lgpoFile)
	Expect(err).NotTo(HaveOccurred())

	for _, zipFile := range zipReader.File {
		if zipFile.Name == fmt.Sprintf("LGPO_30/%s", lgpoFile) {
			var f *os.File
			f, err = os.OpenFile(lgpoPath.Name(), os.O_CREATE|os.O_APPEND|os.O_WRONLY, zipFile.Mode())
			Expect(err).NotTo(HaveOccurred())

			var zipRC io.ReadCloser
			zipRC, err = zipFile.Open()
			Expect(err).NotTo(HaveOccurred())

			_, err = io.Copy(f, zipRC)
			Expect(err).NotTo(HaveOccurred())

			err = f.Close()
			Expect(err).NotTo(HaveOccurred())

			err = zipRC.Close()
			Expect(err).NotTo(HaveOccurred())
		}
	}

	Expect(lgpoPath.Name()).To(BeAnExistingFile())
	Expect(bosh.RunIn(fmt.Sprintf("add-blob %s lgpo/%s", lgpoPath.Name(), lgpoFile), releaseDir)).To(Succeed())

	Expect(bosh.RunIn(fmt.Sprintf("create-release --force --version %s", releaseVersion), releaseDir)).To(Succeed())
	Expect(bosh.RunIn("upload-release", releaseDir)).To(Succeed())

	return releaseVersion
}

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

func (m ManifestProperties) toVarsString() string {
	manifest := m.toMap()

	fmtString := "-v %s=%s "

	var b bytes.Buffer

	for k, v := range manifest {
		if v != "" {
			_, err := fmt.Fprintf(&b, fmtString, k, v)
			Expect(err).NotTo(HaveOccurred())
		}
	}

	boolOperators := []string{
		fmt.Sprintf("-v MountEphemeralDisk=%t", m.MountEphemeralDisk),
		fmt.Sprintf("-v SSHDisabledByDefault=%t", m.SSHDisabledByDefault),
		fmt.Sprintf("-v SecurityComplianceApplied=%t", m.SecurityComplianceApplied),
	}

	_, err := fmt.Fprint(&b, strings.Join(boolOperators, " "))
	Expect(err).NotTo(HaveOccurred())

	return b.String()
}

func (m ManifestProperties) toMap() map[string]string {
	manifest := make(map[string]string)

	manifest["DeploymentName"] = m.DeploymentName
	manifest["ReleaseName"] = m.ReleaseName
	manifest["AZ"] = m.AZ
	manifest["VmType"] = m.VmType
	manifest["RootEphemeralVmType"] = m.RootEphemeralVmType
	manifest["VmExtensions"] = m.VmExtensions
	manifest["Network"] = m.Network
	manifest["StemcellOs"] = m.StemcellOs
	manifest["StemcellVersion"] = m.StemcellVersion
	manifest["ReleaseVersion"] = m.ReleaseVersion
	manifest["DefaultUsername"] = m.DefaultUsername
	manifest["DefaultPassword"] = m.DefaultPassword

	return manifest
}

func downloadLogs(instanceName string, jobName string, index int, bosh *BoshCommand) *gbytes.Buffer {
	tempDir, err := os.MkdirTemp("", "")
	Expect(err).NotTo(HaveOccurred())
	defer os.RemoveAll(tempDir) //nolint:errcheck

	err = bosh.Run(fmt.Sprintf("-d %s logs %s/%d --dir %s", deploymentName, instanceName, index, tempDir))
	Expect(err).NotTo(HaveOccurred())

	matches, err := filepath.Glob(filepath.Join(tempDir, fmt.Sprintf("%s.%s.%d-*.tgz", deploymentName, instanceName, index)))
	Expect(err).NotTo(HaveOccurred())
	Expect(matches).To(HaveLen(1))

	cmd := exec.Command("tar", "xf", matches[0], "-O", fmt.Sprintf("./%s/%s/job-service-wrapper.out.log", jobName, jobName))
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())

	return session.Wait().Out
}

func downloadFile(prefix, sourceUrl string) (string, error) {
	tempFile, err := os.CreateTemp("", prefix)
	if err != nil {
		return "", err
	}

	filename := tempFile.Name()
	f, err := os.OpenFile(filename, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0666)
	if err != nil {
		return "", err
	}
	defer f.Close() //nolint:errcheck

	res, err := http.Get(sourceUrl)
	if err != nil {
		return "", err
	}
	defer res.Body.Close() //nolint:errcheck
	if _, err := io.Copy(f, res.Body); err != nil {
		return "", err
	}

	return filename, nil
}

func (c *TestConfig) deployWithManifest(bosh *BoshCommand, deploymentName string, stemcellVersion string, bwatsVersion string, manifestPath string) error {
	manifestProperties := ManifestProperties{
		DeploymentName:            deploymentName,
		ReleaseName:               "bwats-release",
		AZ:                        c.Az,
		VmType:                    c.VmType,
		RootEphemeralVmType:       c.RootEphemeralVmType,
		VmExtensions:              c.VmExtensions,
		Network:                   c.Network,
		DefaultUsername:           c.DefaultUsername,
		DefaultPassword:           c.DefaultPassword,
		StemcellOs:                c.StemcellOs,
		StemcellVersion:           fmt.Sprintf(`"%s"`, stemcellVersion),
		ReleaseVersion:            bwatsVersion,
		MountEphemeralDisk:        c.MountEphemeralDisk,
		SSHDisabledByDefault:      c.SSHDisabledByDefault,
		SecurityComplianceApplied: c.SecurityComplianceApplied,
	}

	var err error

	if c.RootEphemeralVmType != "" {
		var pwd string
		pwd, err = os.Getwd()
		Expect(err).NotTo(HaveOccurred())
		opsFilePath := filepath.Join(pwd, "assets", "root-disk-as-ephemeral.yml")

		err = bosh.Run(fmt.Sprintf(
			"-d %s deploy %s -o %s %s",
			deploymentName,
			manifestPath,
			opsFilePath,
			manifestProperties.toVarsString(),
		))
	} else {
		err = bosh.Run(fmt.Sprintf("-d %s deploy %s %s", deploymentName, manifestPath, manifestProperties.toVarsString()))
	}

	if err != nil {
		return err
	}

	return nil
}

func (c *TestConfig) deploy(bosh *BoshCommand, deploymentName string, stemcellVersion string, bwatsVersion string) error {
	pwd, err := os.Getwd()
	Expect(err).NotTo(HaveOccurred())
	manifestPath = filepath.Join(pwd, "assets", "manifest.yml")

	return c.deployWithManifest(bosh, deploymentName, stemcellVersion, bwatsVersion, manifestPath)
}
