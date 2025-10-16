package messenger_test

import (
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
)

var _ = Describe("HelpMessenger", func() {
	var (
		buf *Buffer
		m   *messenger.HelpMessenger
	)

	BeforeEach(func() {
		buf = NewBuffer()
		m = messenger.NewHelpMessenger(buf)
	})

	Describe("UsagePreamble", func() {
		It("outputs the expected text", func() {
			executable := "STEMBUILD_EXECUTABLE"
			version := "STEMBUILD_VERSION"
			m.UsagePreamble(executable, version)

			expectedText :=
				fmt.Sprintf("%s version %s, Windows Stemcell Building Tool\n\n", executable, version) +
					fmt.Sprintf("Usage: %s <global options> <command> <command flags>\n\n", executable)

			Eventually(buf).Should(Say(expectedText))
		})
	})

	Describe("PrintCommandPreamble", func() {
		It("outputs the expected text", func() {
			m.PrintCommandPreamble()

			Eventually(buf).Should(Say("Commands:\n"))
		})
	})

	Describe("PrintCommand", func() {
		var (
			command     string
			description = "COMMAND DESCRIPTION"
		)

		Context("when the command name is shorter than 5 characters", func() {
			BeforeEach(func() {
				command = "CMD"
			})

			It("outputs the expected text", func() {
				m.PrintCommand(command, description)

				Eventually(buf).Should(Say(fmt.Sprintf("  %s\t\t%s\n", command, description)))
			})
		})

		Context("when the command name is longer than 5 characters", func() {
			BeforeEach(func() {
				command = "LONG_CMD"
			})

			It("outputs the expected text", func() {
				m.PrintCommand(command, description)

				Eventually(buf).Should(Say(fmt.Sprintf("  %s\t%s\n", command, description)))
			})
		})
	})

	Describe("PrintGlobalFlagPreamble", func() {
		It("outputs the expected text", func() {
			m.PrintGlobalFlagPreamble()

			Eventually(buf).Should(Say("\nGlobal Options:\n"))
		})
	})

	Describe("PrintGlobalFlag", func() {
		var (
			flag  string
			usage = "FLAG USAGE"
		)

		Context("when the flag is longer than 1 character", func() {
			BeforeEach(func() {
				flag = "long-flag"
			})

			It("outputs the expected text", func() {
				m.PrintGlobalFlag(flag, usage)

				Eventually(buf).Should(Say(fmt.Sprintf("  -%s\t%s\n", flag, usage)))
			})
		})

		Context("when the flag is shorter than 1 character", func() {
			BeforeEach(func() {
				flag = "f"
			})

			It("outputs the expected text", func() {
				m.PrintGlobalFlag(flag, usage)

				Eventually(buf).Should(Say(fmt.Sprintf("  -%s\t\t%s\n", flag, usage)))
			})
		})
	})
})
