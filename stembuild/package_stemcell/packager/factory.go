package packager

import (
	"errors"
	"strings"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
)

type Factory struct{}

func (f *Factory) NewPackager(sourceConfig config.SourceConfig, outputConfig config.OutputConfig, logger colorlogger.Logger) (commandparser.Packager, error) {
	source, err := sourceConfig.GetSource()
	if err != nil {
		return nil, err
	}

	switch source {
	case config.VCENTER:
		client :=
			iaas_clients.NewVcenterClient(
				sourceConfig.Username,
				sourceConfig.Password,
				sourceConfig.URL,
				sourceConfig.CaCertFile,
				&iaas_cli.GovcRunner{},
			)

		return &VCenterPackager{
			SourceConfig: sourceConfig,
			OutputConfig: outputConfig,
			Client:       client,
			Logger:       logger,
		}, nil
	case config.VMDK:
		options :=
			config.VmdkOptions{
				VMDKFile:  sourceConfig.Vmdk,
				OSVersion: strings.ToUpper(outputConfig.Os),
				Version:   outputConfig.StemcellVersion,
				OutputDir: outputConfig.OutputDir,
			}

		return &VmdkPackager{
			Stop:         make(chan struct{}),
			BuildOptions: options,
			Logger:       logger,
		}, nil
	default:
		return nil, errors.New("unable to determine packager")
	}
}
