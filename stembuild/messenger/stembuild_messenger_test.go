package messenger_test

import (
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
)

var _ = Describe("StembuildMessenger", func() {
	var (
		outBuf *Buffer
		errBuf *Buffer
		m      *messenger.StembuildMessenger
	)

	BeforeEach(func() {
		outBuf = NewBuffer()
		errBuf = NewBuffer()
		m = messenger.NewStembuildMessenger(outBuf, errBuf)
	})

	Describe("PrintOut", func() {
		It("outputs the expected warning to stdout", func() {
			message := "something went right"
			m.PrintOut(message)

			Eventually(outBuf).Should(Say(message))
		})
	})

	Describe("PrintErr", func() {
		It("outputs the expected warning to stderr", func() {
			message := "something went wrong"
			m.PrintErr(message)

			Eventually(errBuf).Should(Say(message))
		})
	})

	Describe("EnvironmentVariableWarning", func() {
		It("outputs the expected warning to stderr", func() {
			envVar := "SOME_VAR"
			m.EnvironmentVariableWarning(envVar)

			Eventually(errBuf).Should(Say(fmt.Sprintf("Warning: The following environment variable is set and might override flags provided to stembuild: %s\n", envVar)))
		})
	})

	Describe("StemcellAutomationWarning", func() {
		It("outputs the expected warning to stderr", func() {
			m.StemcellAutomationWarning()

			Eventually(errBuf).Should(Say("Unable to write StemcellAutomation.zip"))
		})
	})

	Describe("StemcellAutomationWarning", func() {
		It("outputs the expected warning to stderr", func() {
			m.StemcellAutomationWarning()

			Eventually(errBuf).Should(Say("Unable to write StemcellAutomation.zip"))
		})
	})

	Describe("PrintVersionInfo", func() {
		It("outputs the expected value to stdout", func() {
			executable := "custom-stembuild"
			version := "my.custom.version"
			m.VersionInfo(executable, version)

			Eventually(outBuf).Should(Say(fmt.Sprintf("%s version %s, Windows Stemcell Building Tool\n\n", executable, version)))
		})
	})
})
