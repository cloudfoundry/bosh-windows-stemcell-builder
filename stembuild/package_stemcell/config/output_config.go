package config

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

type OutputConfig struct {
	Os              string
	StemcellVersion string
	OutputDir       string
}

func (c OutputConfig) ValidateConfig() error {
	if !IsValidOS(c.Os) {
		return fmt.Errorf("versioning error; parsed os version is: %s\n", c.Os) //nolint:staticcheck
	}
	if !IsValidStemcellVersion(c.StemcellVersion) {
		return fmt.Errorf( //nolint:staticcheck
			"versioning error; parsed stemcell version is: %s. Expected format [NUMBER].[NUMBER] or [NUMBER].[NUMBER].[NUMBER]\n",
			c.StemcellVersion,
		)
	}

	if c.OutputDir == "" || c.OutputDir == "." {
		cwd, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("error getting working directory %s", err) //nolint:staticcheck
		}
		c.OutputDir = cwd
	} else if err := ValidateOrCreateOutputDir(c.OutputDir); err != nil {
		return err
	}

	name := filepath.Join(c.OutputDir, stemcellFilename(c.StemcellVersion, c.Os))
	if _, err := os.Stat(name); !os.IsNotExist(err) {
		return fmt.Errorf("error with output file (%s): %v (file may already exist)", name, err) //nolint:staticcheck
	}

	return nil
}

func IsValidOS(os string) bool {
	switch os {
	case "2012R2", "1803", "2016", "2019", "2022":
		return true
	default:
		return false
	}
}

func ValidateOrCreateOutputDir(outputDir string) error {

	fi, err := os.Stat(outputDir)
	if err != nil && os.IsNotExist(err) {
		if err = os.Mkdir(outputDir, 0700); err != nil {
			return err
		}
	} else if err != nil || fi == nil {
		return fmt.Errorf("error opening output directory (%s): %s\n", outputDir, err) //nolint:staticcheck
	} else if !fi.IsDir() {
		return fmt.Errorf("output argument (%s): is not a directory\n", outputDir) //nolint:staticcheck
	}

	return nil
}

func IsValidStemcellVersion(version string) bool {

	if version == "" {
		return false
	}

	patterns := []string{
		`^\d{1,}\.\d{1,}$`,
		`^\d{1,}\.\d{1,}-build\.\d{1,}$`,
		`^\d{1,}\.\d{1,}\.\d{1,}$`,
		`^\d{1,}\.\d{1,}\.\d{1,}-build\.\d{1,}$`,
		`^\d{1,}\.\d{1,}\.\d{1,}-manual\.\d{1,}$`,
	}

	for _, pattern := range patterns {
		if regexp.MustCompile(pattern).MatchString(version) {
			return true
		}
	}

	return false
}

func stemcellFilename(version, os string) string {
	return fmt.Sprintf("bosh-stemcell-%s-vsphere-esxi-windows%s-go_agent.tgz",
		version, os)
}
