package main

import (
	"context"
	"flag"
	"os"
	"path"
	"strings"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/google/subcommands"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/assets"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"
)

func main() {
	var gf commandparser.GlobalFlags
	fs := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	fs.BoolVar(&gf.Debug, "debug", false, "Print lots of debugging information")
	fs.BoolVar(&gf.Color, "color", false, "Colorize debug output")
	fs.BoolVar(&gf.ShowVersion, "version", false, "Show Stembuild version")
	fs.BoolVar(&gf.ShowVersion, "v", false, "Stembuild version (shorthand)")
	commander := subcommands.NewCommander(fs, path.Base(os.Args[0]))

	stembuildMessenger := messenger.NewStembuildMessenger(commander.Output, commander.Error)
	logLevel := colorlogger.NONE
	if gf.Debug {
		logLevel = colorlogger.DEBUG
	}
	logger := colorlogger.New(logLevel, gf.Color, commander.Error)

	envs := os.Environ()
	for _, env := range envs {
		envName := strings.Split(env, "=")[0]
		if strings.HasPrefix(envName, "GOVC_") || strings.HasPrefix(envName, "GOVMOMI_") {
			stembuildMessenger.EnvironmentVariableWarning(envName)
		}
	}

	s := "./StemcellAutomation.zip"
	err := os.WriteFile(s, assets.StemcellAutomation, 0644)
	if err != nil {
		stembuildMessenger.StemcellAutomationWarning()
		os.Exit(1)
	}

	var commands []subcommands.Command
	helpCmd := commandparser.NewStembuildHelp(commander, fs, &commands)
	commander.Register(helpCmd, "")
	commands = append(commands, helpCmd)

	packageCmd := commandparser.NewPackageCommand(version.New(), &packager.Factory{}, logger, stembuildMessenger)
	packageCmd.GlobalFlags = &gf
	commander.Register(packageCmd, "")
	commands = append(commands, packageCmd)

	constructCmd := commandparser.NewConstructCmd(context.Background(), &construct.Factory{}, &vcenter_manager.ManagerFactory{}, &commandparser.ConstructValidator{}, stembuildMessenger)
	constructCmd.GlobalFlags = &gf
	commander.Register(constructCmd, "")
	commands = append(commands, constructCmd)

	// Override the default usage text of Google's Subcommand with our own
	fs.Usage = func() { helpCmd.Explain(commander.Error) }

	fs.Parse(os.Args[1:]) //nolint:errcheck
	if gf.ShowVersion {
		stembuildMessenger.VersionInfo(path.Base(os.Args[0]), version.Current)
		os.Remove(s) //nolint:errcheck
		os.Exit(0)
	}

	ctx := context.Background()
	i := int(commander.Execute(ctx))
	os.Remove(s) //nolint:errcheck
	os.Exit(i)
}
