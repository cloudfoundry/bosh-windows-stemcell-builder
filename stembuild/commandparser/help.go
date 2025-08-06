package commandparser

import (
	"context"
	"flag"
	"io"
	"os"
	"path"

	"github.com/google/subcommands"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version"
)

/*
This is a wrapper for Google's Subcommand's HelpCommand so that we can
override the help text when the user just enters the `help` command in the command
line.
*/

type stembuildHelp struct {
	topLevelFlags *flag.FlagSet
	commands      *[]subcommands.Command
	commander     *subcommands.Commander
}

func NewStembuildHelp(commander *subcommands.Commander, topLevelFlags *flag.FlagSet, commands *[]subcommands.Command) *stembuildHelp {
	var sh = stembuildHelp{}
	sh.commander = commander
	sh.topLevelFlags = topLevelFlags
	sh.commands = commands

	return &sh
}

func (h *stembuildHelp) Name() string {
	return h.commander.HelpCommand().Name()
}

func (h *stembuildHelp) Synopsis() string {
	return "Describe commands and their syntax"
}

func (h *stembuildHelp) SetFlags(fs *flag.FlagSet) {
	h.commander.HelpCommand().SetFlags(fs)
}

func (h *stembuildHelp) Usage() string {
	return h.commander.HelpCommand().Usage()
}

func (h *stembuildHelp) Execute(ctx context.Context, flagSet *flag.FlagSet, args ...interface{}) subcommands.ExitStatus {
	switch flagSet.NArg() {
	case 0:
		h.Explain(h.commander.Output)
		return subcommands.ExitSuccess

	default:
		return h.commander.HelpCommand().Execute(ctx, flagSet, args)
	}
}

func (h *stembuildHelp) Explain(output io.Writer) {
	helpMessenger := messenger.NewHelpMessenger(output)

	helpMessenger.UsagePreamble(path.Base(os.Args[0]), version.Current)

	helpMessenger.PrintCommandPreamble()
	for _, command := range *h.commands {
		helpMessenger.PrintCommand(command.Name(), command.Synopsis())
	}

	helpMessenger.PrintGlobalFlagPreamble()
	h.topLevelFlags.VisitAll(func(f *flag.Flag) {
		helpMessenger.PrintGlobalFlag(f.Name, f.Usage)
	})
}
