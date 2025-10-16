package messenger_test

import (
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
})
