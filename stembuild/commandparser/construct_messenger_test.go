package commandparser_test

import (
	"errors"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
)

var _ = Describe("ConstructMessenger", func() {
	var (
		cm commandparser.ConstructCmdMessenger
		g  *Buffer
	)

	BeforeEach(func() {
		g = NewBuffer()
		cm = commandparser.ConstructCmdMessenger{OutputChannel: g}
	})

	Describe("ArgumentsNotProvided", func() {
		It("should output an appropriate error", func() {
			cm.ArgumentsNotProvided()
			Eventually(g).Should(Say("Not all required parameters were provided. See stembuild --help for more details"))
		})
	})

	Describe("LGPONotFound", func() {
		It("should output an appropriate error", func() {
			cm.LGPONotFound()
			Eventually(g).Should(Say("Could not find LGPO.zip in the current directory"))
		})
	})

	Describe("CannotConnectToVM", func() {
		It("should output an appropriate error", func() {
			connectionError := errors.New("some connection error")
			cm.CannotConnectToVM(connectionError)
			Eventually(g).Should(Say("Cannot connect to VM: %s", connectionError))
		})
	})

	Describe("CannotPrepareVM", func() {
		It("should output an appropriate error", func() {
			preparationError := errors.New("PrepareVM failed")
			cm.CannotPrepareVM(preparationError)
			Eventually(g).Should(Say("Could not prepare VM: %s", preparationError))
		})
	})
})
