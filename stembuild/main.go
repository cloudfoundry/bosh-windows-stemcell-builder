package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path"
	"strings"

	"github.com/google/subcommands"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/assets"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/construct"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/iaas_cli/iaas_clients/vcenter_manager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/packager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"
)

func main() {
	envs := os.Environ()
	for _, env := range envs {
		envName := strings.Split(env, "=")[0]
		if strings.HasPrefix(envName, "GOVC_") || strings.HasPrefix(envName, "GOVMOMI_") {
			fmt.Fprintf(os.Stderr, "Warning: The following environment variable is set and might override flags provided to stembuild: %s\n", envName) //nolint:errcheck
		}
	}

	s := "./StemcellAutomation.zip"
	err := os.WriteFile(s, assets.StemcellAutomation, 0644)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Unable to write StemcellAutomation.zip") //nolint:errcheck
		os.Exit(1)
	}

	var gf commandparser.GlobalFlags
	packageCmd := commandparser.NewPackageCommand(version.NewVersionGetter(), &packager.Factory{}, &commandparser.PackageMessenger{Output: os.Stderr})
	packageCmd.GlobalFlags = &gf
	constructCmd := commandparser.NewConstructCmd(context.Background(), &construct.Factory{}, &vcenter_manager.ManagerFactory{}, &commandparser.ConstructValidator{}, &commandparser.ConstructCmdMessenger{OutputChannel: os.Stderr})
	constructCmd.GlobalFlags = &gf

	var commands = make([]subcommands.Command, 0)

	fs := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	fs.BoolVar(&gf.Debug, "debug", false, "Print lots of debugging information")
	fs.BoolVar(&gf.Color, "color", false, "Colorize debug output")
	fs.BoolVar(&gf.ShowVersion, "version", false, "Show Stembuild version")
	fs.BoolVar(&gf.ShowVersion, "v", false, "Stembuild version (shorthand)")

	commander := subcommands.NewCommander(fs, path.Base(os.Args[0]))

	sh := commandparser.NewStembuildHelp(commander, fs, &commands)
	commander.Register(sh, "")
	commands = append(commands, sh)

	commander.Register(packageCmd, "")
	commander.Register(constructCmd, "")

	commands = append(commands, packageCmd)
	commands = append(commands, constructCmd)

	// Override the default usage text of Google's Subcommand with our own
	fs.Usage = func() { sh.Explain(commander.Error) }

	fs.Parse(os.Args[1:]) //nolint:errcheck
	if gf.ShowVersion {
		fmt.Fprintf(os.Stdout, "%s version %s, Windows Stemcell Building Tool\n\n", path.Base(os.Args[0]), version.Version) //nolint:errcheck
		os.Remove(s)                                                                                                        //nolint:errcheck
		os.Exit(0)
	}

	ctx := context.Background()
	i := int(commander.Execute(ctx))
	os.Remove(s) //nolint:errcheck
	os.Exit(i)
}
