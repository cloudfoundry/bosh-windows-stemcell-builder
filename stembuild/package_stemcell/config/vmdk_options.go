package config

type VmdkOptions struct {
	OSVersion string `yaml:"os_version"`
	OutputDir string `yaml:"output_dir"`
	Version   string `yaml:"version"`
	VMDKFile  string `yaml:"vmdk_file"`
}
