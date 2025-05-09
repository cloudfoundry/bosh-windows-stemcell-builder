package config

type SourceConfig struct {
	GuestVmIp       string
	GuestVMUsername string
	GuestVMPassword string
	VCenterUrl      string
	VCenterUsername string
	VCenterPassword string
	VmInventoryPath string
	CaCertFile      string
	SetupFlags      []string
}
