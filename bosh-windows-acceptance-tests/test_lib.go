package bosh_windows_acceptance_tests_test


func runTest(testName string) error {
	return bosh.Run(fmt.Sprintf("-d %s run-errand --download-logs %s --tty", deploymentName, testName))
}

func uploadStemcell(config *Config, bosh *BoshCommand) {
	matches, err := filepath.Glob(config.Stemcellpath)
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
	goZipPath, err := downloadFile("golang-", GolangURL)
	Expect(err).NotTo(HaveOccurred())
	releaseDir := filepath.Join(pwd, "assets", "bwats-release")
	Expect(bosh.RunIn(fmt.Sprintf("add-blob %s golang-windows/%s", goZipPath, GoZipFile), releaseDir)).To(Succeed())

	lgpoZipPath, err := downloadFile("lgpo-", LgpoUrl)
	Expect(err).NotTo(HaveOccurred())

	zipReader, err := zip.OpenReader(lgpoZipPath)
	Expect(err).NotTo(HaveOccurred())

	lgpoPath, err := ioutil.TempFile("", lgpoFile)
	Expect(err).NotTo(HaveOccurred())

	for _, zipFile := range zipReader.File {
		if zipFile.Name == lgpoFile {
			filename := lgpoPath.Name()
			f, err := os.OpenFile(filename, os.O_CREATE|os.O_APPEND|os.O_WRONLY, zipFile.Mode())
			Expect(err).NotTo(HaveOccurred())

			zipRC, err := zipFile.Open()
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

	_, err := fmt.Fprintf(&b, strings.Join(boolOperators, " "))
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
	tempDir, err := ioutil.TempDir("", "")
	Expect(err).NotTo(HaveOccurred())
	defer os.RemoveAll(tempDir)

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

func getTimestampInMs() int64 {
	return time.Now().UTC().UnixNano() / int64(time.Millisecond)
}

func fetchStemcellInfo(stemcellPath string) (StemcellYML, error) {
	var stemcellInfo StemcellYML
	tempDir, err := ioutil.TempDir("", "")
	Expect(err).NotTo(HaveOccurred())
	defer os.RemoveAll(tempDir)

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

	stemcellMF, err := ioutil.ReadFile(fmt.Sprintf("%s/%s", tempDir, "stemcell.MF"))
	Expect(err).NotTo(HaveOccurred())

	err = yaml.Unmarshal(stemcellMF, &stemcellInfo)
	Expect(err).NotTo(HaveOccurred())
	Expect(stemcellInfo.Version).ToNot(BeNil())
	Expect(stemcellInfo.Version).ToNot(BeEmpty())

	return stemcellInfo, nil
}

func downloadFile(prefix, sourceUrl string) (string, error) {
	tempfile, err := ioutil.TempFile("", prefix)
	if err != nil {
		return "", err
	}

	filename := tempfile.Name()
	f, err := os.OpenFile(filename, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0666)
	if err != nil {
		return "", err
	}
	defer f.Close()

	res, err := http.Get(sourceUrl)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if _, err := io.Copy(f, res.Body); err != nil {
		return "", err
	}

	return filename, nil
}

func (c *Config) deployWithManifest(bosh *BoshCommand, deploymentName string, stemcellVersion string, bwatsVersion string, manifestPath string) error {
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
		pwd, err := os.Getwd()
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

func (c *Config) deploy(bosh *BoshCommand, deploymentName string, stemcellVersion string, bwatsVersion string) error {
	pwd, err := os.Getwd()
	Expect(err).NotTo(HaveOccurred())
	manifestPath = filepath.Join(pwd, "assets", "manifest.yml")

	return c.deployWithManifest(bosh, deploymentName, stemcellVersion, bwatsVersion, manifestPath)
}
