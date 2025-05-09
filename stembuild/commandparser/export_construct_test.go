package commandparser

import "github.gwd.broadcom.net/TNZ/bosh-windows-stemcell-builder/stembuild/construct/config"

func (p *ConstructCmd) GetSourceConfig() config.SourceConfig {
	return p.sourceConfig
}
