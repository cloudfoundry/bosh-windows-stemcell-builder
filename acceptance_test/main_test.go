package windows_stemcell_acceptance_test

import (
	"archive/zip"
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
const GolangURL = "https://go.dev/dl/" + GoZipFile
const LgpoUrl = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
const lgpoFile = "LGPO.exe"
const windowsVersion = "windows-2019"

var (
	boshCommand     *BoshCommand
	deploymentName  string
	manifestPath    string
	stemcellName    string
	stemcellVersion string
	releaseVersion  string
	testConfig      *TestConfig
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
	deploymentName = buildDeploymentName("stemcell-acceptance-test")

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
	if testConfig.SkipCleanup {
		return
	}

	err := boshCommand.Run(fmt.Sprintf("--deployment=%s delete-deployment", deploymentName))
	Expect(err).NotTo(HaveOccurred())
	err = boshCommand.Run(fmt.Sprintf("delete-stemcell %s/%s", stemcellName, stemcellVersion))
	Expect(err).NotTo(HaveOccurred())
	err = boshCommand.Run(fmt.Sprintf("delete-release bwats-release/%s", releaseVersion))
	Expect(err).NotTo(HaveOccurred())

	if boshCommand.CertPath != "" {
		Expect(os.RemoveAll(boshCommand.CertPath)).To(Succeed())
	}
})

var _ = Describe("BOSH Windows", func() {
	It("can run a job that relies on a package", func() {
		time.Sleep(60 * time.Second)
		Eventually(
			downloadLogs("check-multiple", 0, "./simple-job/simple-job/job-service-wrapper.out.log", boshCommand),
		).WithTimeout(time.Second * 65).Should(gbytes.Say("60 seconds passed"))
	})

	It("checks system dependencies and security, auto update has turned off, currently has a Service StartType of 'Manual' and initially had a StartType of 'Delayed', and password is randomized", func() {
		err := boshCommand.RunErrand("check-system", deploymentName)
		if err != nil {
			downloadLogs("check-multiple", 0, "./check-system/combined-output.log", boshCommand)
			Expect(err).NotTo(HaveOccurred())
		}
	})

	It("is fully updated", func() {
		err := boshCommand.RunErrand("check-updates", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	It("has all certificate authority certs that are present on the Windows Update Server", func() {
		err := boshCommand.RunErrand("check-wu-certs", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	It("mounts ephemeral disks when asked to do so and does not mount them otherwise", func() {
		err := boshCommand.RunErrand("ephemeral-disk", deploymentName)
		Expect(err).NotTo(HaveOccurred())
	})

	Context("ssh enabled", func() {
		It("allows SSH connection", func() {
			err := boshCommand.Run(fmt.Sprintf("--deployment=%s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())
		})

		It("cleans up ssh users after a successful connection", func() {
			err := boshCommand.Run(fmt.Sprintf("--deployment=%s ssh --opts=-T --command=exit", deploymentName))
			Expect(err).NotTo(HaveOccurred())

			// test for C:\Users and net users not having any bosh_* users
			Eventually(func() error {
				return boshCommand.RunErrand("check-ssh", deploymentName)
			}, 2*time.Minute, 10*time.Second).Should(Succeed())
		})
	})
})

func buildDeploymentName(baseName string) string {
	return fmt.Sprintf(
		"%s-%s-%s",
		windowsVersion,
		baseName,
		time.Now().Format("2006-01-02T15h04s05"),
	)
}

func getTimestamp() string {
	return time.Now().Format("20060102150405")
}

type TestConfig struct {
	Bosh struct {
		CaCert       string `json:"ca_cert"`
		Client       string `json:"client"`
		ClientSecret string `json:"client_secret"`
		Target       string `json:"target"`
	} `json:"bosh"`
	StemcellPath        string `json:"stemcell_path"`
	StemcellOs          string `json:"stemcell_os"`
	Az                  string `json:"az"`
	VmType              string `json:"vm_type"`
	RootEphemeralVmType string `json:"root_ephemeral_vm_type"`
	VmExtensions        string `json:"vm_extensions"`
	Network             string `json:"network"`
	DefaultUsername     string `json:"default_username"`
	DefaultPassword     string `json:"default_password"`
	SkipCleanup         bool   `json:"skip_cleanup"`
	NtpServers          string `json:"ntp_servers"`
}

type StemcellYML struct {
	Version string `yaml:"version"`
	Name    string `yaml:"name"`
}

func fetchStemcellInfo(stemcellPath string) (StemcellYML, error) {
	var stemcellInfo StemcellYML
	tempDir := GinkgoT().TempDir()

	cmd := exec.Command("tar", "xf", stemcellPath, "-C", tempDir, "stemcell.MF")
	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())
	Eventually(session).WithTimeout(20 * time.Minute).Should(gexec.Exit())

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
		By(fmt.Sprintf("Found BWATS_BOSH_TIMEOUT: '%s'", s))

		if err != nil {
			GinkgoWriter.Printf("Error parsing BWATS_BOSH_TIMEOUT (%s): %s - falling back to default\n", s, err)
		}
	}
	By(fmt.Sprintf("Setting BoshCommand.Timeout = '%s'", timeout))

	return &BoshCommand{
		DirectorIP:   config.Bosh.Target,
		Client:       config.Bosh.Client,
		ClientSecret: config.Bosh.ClientSecret,
		CertPath:     boshCertPath,
		Timeout:      timeout,
	}
}

func (c *BoshCommand) args(command string) []string {
	commonArgs := []string{
		"--non-interactive",
		fmt.Sprintf("--environment=%s", c.DirectorIP),
		fmt.Sprintf("--client=%s", c.Client),
		fmt.Sprintf("--client-secret=%s", c.ClientSecret),
	}
	if c.CertPath != "" {
		commonArgs = append(commonArgs, fmt.Sprintf("--ca-cert=%s", c.CertPath))
	}

	commandArgs := strings.Split(command, " ")

	args := append(commonArgs, commandArgs...)

	return args
}

func (c *BoshCommand) Run(command string) error {
	return c.RunIn(command, "")
}

func (c *BoshCommand) RunErrand(errandName string, deploymentName string) error {
	return c.Run(fmt.Sprintf("--deployment=%s run-errand --download-logs %s --tty", deploymentName, errandName))
}

func (c *BoshCommand) RunInStdOut(command, dir string) ([]byte, error) {
	cmd := exec.Command("bosh", c.args(command)...)

	if dir != "" {
		cmd.Dir = dir
	}
	GinkgoWriter.Printf("\nRUNNING: %q\nWorking Dir: %q\n", strings.Join(cmd.Args, " "), cmd.Dir)

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	if err != nil {
		return nil, err
	}
	Eventually(session).WithTimeout(c.Timeout).Should(gexec.Exit())

	exitCode := session.ExitCode()
	stdout := session.Out.Contents()
	if exitCode != 0 {
		var stderr []byte
		if session.Err != nil {
			stderr = session.Err.Contents()
		}
		return stdout,
			fmt.Errorf(
				"Non-zero exit code for cmd %q: %d\nSTDERR:\n%s\nSTDOUT:%s\n---------------------------------\n",
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

	releaseVersion = fmt.Sprintf("0.dev+%s", getTimestamp())
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
	DeploymentName      string
	ReleaseName         string
	AZ                  string
	VmType              string
	RootEphemeralVmType string
	VmExtensions        string
	Network             string
	StemcellOs          string
	StemcellVersion     string
	ReleaseVersion      string
	DefaultUsername     string
	DefaultPassword     string
}

func (m ManifestProperties) toVarsFlags() []string {
	var varFlags []string

	for k, v := range m.toMap() {
		if v != "" {
			varFlags = append(varFlags, fmt.Sprintf(`--var=%s="%s"`, k, v))
		}
	}

	return varFlags
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

func downloadLogs(instanceName string, index int, logPath string, bosh *BoshCommand) *gbytes.Buffer {
	tempDir := GinkgoT().TempDir()

	err := bosh.Run(fmt.Sprintf("--deployment=%s logs %s/%d --dir %s", deploymentName, instanceName, index, tempDir))
	Expect(err).NotTo(HaveOccurred())

	matches, err := filepath.Glob(filepath.Join(tempDir, fmt.Sprintf("%s.%s.%d-*.tgz", deploymentName, instanceName, index)))
	Expect(err).NotTo(HaveOccurred())
	Expect(matches).To(HaveLen(1))

	cmd := exec.Command("tar", "xf", matches[0], "-O", logPath)
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

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return "", fmt.Errorf("failed to download file: HTTP %d %s", res.StatusCode, res.Status)
	}

	_, err = io.Copy(f, res.Body)
	if err != nil {
		return "", err
	}

	return filename, nil
}

func (c *TestConfig) deployWithManifest(bosh *BoshCommand, deploymentName string, stemcellVersion string,
	bwatsVersion string, manifestPath string, varsFiles []string, opsFiles []string) error {
	manifestProperties := ManifestProperties{
		DeploymentName:      deploymentName,
		ReleaseName:         "bwats-release",
		AZ:                  c.Az,
		VmType:              c.VmType,
		RootEphemeralVmType: c.RootEphemeralVmType,
		VmExtensions:        c.VmExtensions,
		Network:             c.Network,
		DefaultUsername:     c.DefaultUsername,
		DefaultPassword:     c.DefaultPassword,
		StemcellOs:          c.StemcellOs,
		StemcellVersion:     stemcellVersion,
		ReleaseVersion:      bwatsVersion,
	}

	var opsFileArgs strings.Builder
	for _, path := range opsFiles {
		opsFileArgs.WriteString(fmt.Sprintf("--ops-file=%s ", path)) //nolint:staticcheck
	}
	cmdArgs := []string{
		fmt.Sprintf("--deployment=%s", deploymentName),
		"deploy",
		manifestPath,
	}
	for _, path := range varsFiles {
		cmdArgs = append(cmdArgs, fmt.Sprintf("--vars-file=%s", path))
	}
	for _, path := range opsFiles {
		cmdArgs = append(cmdArgs, fmt.Sprintf("--ops-file=%s", path))
	}
	cmdArgs = append(cmdArgs, manifestProperties.toVarsFlags()...)

	return bosh.Run(strings.Join(cmdArgs, " "))
}

func (c *TestConfig) deploy(bosh *BoshCommand, deploymentName string, stemcellVersion string, bwatsVersion string) error {
	pwd, err := os.Getwd()
	Expect(err).NotTo(HaveOccurred())
	manifestPath = filepath.Join(pwd, "assets", "manifest.yml")

	var opsFilePaths []string
	var varsFilePaths []string
	if c.RootEphemeralVmType != "" {
		opsFilePaths = append(opsFilePaths, filepath.Join(pwd, "assets", "root-disk-as-ephemeral.yml"))
	}

	if c.NtpServers != "" {
		servers := strings.Split(c.NtpServers, ",")
		var validServers []string
		for _, s := range servers {
			if trimmed := strings.TrimSpace(s); trimmed != "" {
				validServers = append(validServers, trimmed)
			}
		}

		if len(validServers) > 0 {
			varsData := map[string][]string{
				"NtpServers": validServers,
			}
			yamlBytes, err := yaml.Marshal(varsData)
			Expect(err).NotTo(HaveOccurred())

			varsFilePath := filepath.Join(pwd, "assets", "add-ntp-vars.yml")
			err = os.WriteFile(varsFilePath, yamlBytes, 0644)
			Expect(err).NotTo(HaveOccurred())

			varsFilePaths = append(varsFilePaths, varsFilePath)
			opsFilePaths = append(opsFilePaths, filepath.Join(pwd, "assets", "add-ntp.yml"))
		}
	}

	return c.deployWithManifest(bosh, deploymentName, stemcellVersion, bwatsVersion, manifestPath, varsFilePaths, opsFilePaths)
}
