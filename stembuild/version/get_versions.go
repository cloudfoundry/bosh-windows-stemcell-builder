package version

import (
	"fmt"
	"strings"
)

type VersionGetterModifier interface {
	Modify(*VersionGetter)
}

func NewVersionGetter(modifiers ...VersionGetterModifier) *VersionGetter {
	v := &VersionGetter{
		Version: Version,
	}

	for _, modifier := range modifiers {
		modifier.Modify(v)
	}

	return v
}

type VersionGetter struct {
	Version string
}

func (v *VersionGetter) GetVersion() string {
	stringArr := strings.Split(v.Version, ".")
	stringArr = stringArr[0:2]

	return strings.Join(stringArr, ".")
}

func (v *VersionGetter) GetVersionWithPatchNumber(patchNumber string) string {
	return fmt.Sprintf("%s.%s", v.GetVersion(), patchNumber)
}

func (v *VersionGetter) GetOs() string {
	stringArr := strings.Split(v.Version, ".")
	os := stringArr[0]

	if os == "1200" {
		return "2012R2"
	}

	return os
}

var Version = "dev"
