package config

import (
	"errors"
)

type SourceConfig struct {
	Vmdk            string
	URL             string
	Username        string
	Password        string
	VmInventoryPath string
	CaCertFile      string
}

type Source int

const (
	VMDK Source = iota
	VCENTER
	NIL
)

func (c SourceConfig) GetSource() (Source, error) {
	if c.vmdkProvided() && c.partialvCenterProvided() {
		return NIL, errors.New("configuration provided for VMDK & vCenter sources")
	}

	if c.vmdkProvided() {
		return VMDK, nil
	}

	if c.vcenterProvided() {
		return VCENTER, nil
	}

	if c.partialvCenterProvided() {
		return NIL, errors.New("missing vCenter configurations")
	}

	return NIL, errors.New("no configuration was provided")
}

func (c SourceConfig) vmdkProvided() bool {
	return c.Vmdk != ""
}

func (c SourceConfig) vcenterProvided() bool {
	if c.VmInventoryPath != "" && c.Username != "" && c.Password != "" && c.URL != "" {
		return true
	}
	return false
}

// At least one vCenter configuration given
func (c SourceConfig) partialvCenterProvided() bool {
	if c.VmInventoryPath != "" || c.Username != "" || c.Password != "" || c.URL != "" {
		return true
	}
	return false
}
