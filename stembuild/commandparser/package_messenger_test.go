package commandparser_test

import (
	"errors"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
)

var _ = Describe("PackageMessenger", func() {
	var (
		buf       *Buffer
		messenger *commandparser.PackageMessenger
	)

	BeforeEach(func() {
		buf = NewBuffer()
		messenger = &commandparser.PackageMessenger{Output: buf}
	})

	It("writes the error message to the write when InvalidOutputConfig is called", func() {
		message := "the output config is invalid"
		messenger.InvalidOutputConfig(errors.New(message))
		Eventually(buf).Should(Say(message))
	})

	It("writes the error message to the writer when CannotCreatePackager is called", func() {
		message := "there was a problem creating a packager"
		messenger.CannotCreatePackager(errors.New(message))
		Eventually(buf).Should(Say(message))
	})

	It("writes the error message to the writer when DoesNotHaveEnoughSpace is called", func() {
		message := "not enough space to create package"
		messenger.DoesNotHaveEnoughSpace(errors.New(message))
		Eventually(buf).Should(Say(message))
	})

	It("writes the error message to the writer when SourceParametersAreInvalid is called", func() {
		message := "source parameters invalid"
		messenger.SourceParametersAreInvalid(errors.New(message))
		Eventually(buf).Should(Say(message))
	})

	It("writes the error messages to the writer when PackageFailed is called", func() {
		message := "package failed"
		messenger.PackageFailed(errors.New(message))
		Eventually(buf).Should(Say(message))
		Eventually(buf).Should(Say("Please provide the error logs to bosh-windows-eng@pivotal.io"))
	})
})
