package commandparser

import "github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct/config"

func (p *ConstructCmd) GetSourceConfig() config.SourceConfig {
	return p.sourceConfig
}
