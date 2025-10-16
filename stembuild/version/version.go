package version

import (
	"fmt"
	"strings"
)

var Current = "dev"

func New() *Getter {
	return &Getter{
		Version: Current,
	}
}

type Getter struct {
	Version string
}

func (g *Getter) GetVersion() string {
	majorMinor := g.versionArray()[0:2]

	return strings.Join(majorMinor, ".")
}

func (g *Getter) GetVersionWithPatchNumber(patchNumber string) string {
	return fmt.Sprintf("%s.%s", g.GetVersion(), patchNumber)
}

func (g *Getter) GetOs() string {
	osIdentifier := g.versionArray()[0]

	return osIdentifier
}

func (g *Getter) versionArray() []string {
	return strings.Split(g.Version, ".")
}
