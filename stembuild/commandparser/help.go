package commandparser

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"path"

	"github.com/google/subcommands"

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

func (h *stembuildHelp) Execute(c context.Context, f *flag.FlagSet, args ...interface{}) subcommands.ExitStatus {
	switch f.NArg() {
	case 0:
		h.Explain(h.commander.Output)
		return subcommands.ExitSuccess

	default:
		return h.commander.HelpCommand().Execute(c, f, args)
	}
}

func (h *stembuildHelp) Explain(w io.Writer) {

	fmt.Fprintf(w, "%s version %s, Windows Stemcell Building Tool\n\n", path.Base(os.Args[0]), version.Version) //nolint:errcheck
	fmt.Fprintf(w, "Usage: %s <global options> <command> <command flags>\n\n", path.Base(os.Args[0]))           //nolint:errcheck

	fmt.Fprint(w, "Commands:\n") //nolint:errcheck
	for _, command := range *h.commands {
		if len(command.Name()) < 5 { // This help align the synopses when the commands are of different lengths
			fmt.Fprintf(w, "  %s\t\t%s\n", command.Name(), command.Synopsis()) //nolint:errcheck
		} else {
			fmt.Fprintf(w, "  %s\t%s\n", command.Name(), command.Synopsis()) //nolint:errcheck
		}
	}

	fmt.Fprint(w, "\nGlobal Options:\n") //nolint:errcheck
	h.topLevelFlags.VisitAll(func(f *flag.Flag) {
		if len(f.Name) > 1 {
			fmt.Fprintf(w, "  -%s\t%s\n", f.Name, f.Usage) //nolint:errcheck
		} else {
			fmt.Fprintf(w, "  -%s\t\t%s\n", f.Name, f.Usage) //nolint:errcheck
		}
	})
}
