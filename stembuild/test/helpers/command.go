package helpers

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo/v2"    //nolint:staticcheck
	. "github.com/onsi/gomega"       //nolint:staticcheck
	. "github.com/onsi/gomega/gexec" //nolint:staticcheck
)

const (
	DebugCommandPrefix = "\nCMD>"
	DebugOutPrefix     = "OUT: "
	DebugErrPrefix     = "ERR: "
)

func Stembuild(command string, args ...string) *Session {
	return StembuildWithEnv(map[string]string{}, command, args...)
}

func RunCommandInDir(workingDir, command string, args ...string) *Session {
	WriteCommand(command, args)
	session, err := Start(
		&exec.Cmd{
			Path: command,
			Args: append([]string{command}, args...),
			Dir:  workingDir,
		},
		NewPrefixedWriter(DebugOutPrefix, GinkgoWriter),
		NewPrefixedWriter(DebugErrPrefix, GinkgoWriter))
	Expect(err).NotTo(HaveOccurred())
	return session
}

func StembuildWithEnv(passedEnv map[string]string, command string, args ...string) *Session {
	WriteCommand(command, args)

	execComand := exec.Command(command, args...)
	env := os.Environ()
	for key, val := range passedEnv {
		env = AddOrReplaceEnvironment(env, key, val)
	}
	execComand.Env = env

	session, err := Start(
		execComand,
		NewPrefixedWriter(DebugOutPrefix, GinkgoWriter),
		NewPrefixedWriter(DebugErrPrefix, GinkgoWriter))
	Expect(err).NotTo(HaveOccurred())
	return session
}

func WriteCommand(command string, args []string) {
	display := append([]string{DebugCommandPrefix, command}, args...)
	GinkgoWriter.Write([]byte(strings.Join(append(display, "\n"), " "))) //nolint:errcheck
}

// AddOrReplaceEnvironment will update environment if it already exists or will add
// a new environment with the given environment name and details.
func AddOrReplaceEnvironment(env []string, newEnvName string, newEnvVal string) []string {
	var found bool
	for i, envPair := range env {
		splitEnv := strings.Split(envPair, "=")
		if splitEnv[0] == newEnvName {
			env[i] = fmt.Sprintf("%s=%s", newEnvName, newEnvVal)
			found = true
		}
	}

	if !found {
		env = append(env, fmt.Sprintf("%s=%s", newEnvName, newEnvVal))
	}
	return env
}
