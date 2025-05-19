package colorlogger_test

import (
	"bytes"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
)

var _ = Describe("Stdout", func() {
	It("write debug output when log level is debug", func() {
		buf := bytes.Buffer{}

		Expect(colorlogger.DEBUG).To(Equal(0))
		logger := colorlogger.New(colorlogger.DEBUG, false, &buf)

		message := "This is a test"

		logger.Printf(message)
		Expect(buf.String()).To(Equal("debug: " + message + "\n"))
	})

	It("write no debug output when log level is NONE", func() {
		buf := bytes.Buffer{}

		logger := colorlogger.New(colorlogger.NONE, false, &buf)

		message := "This is a test"

		logger.Printf(message)
		Expect(buf.String()).To(BeEmpty())
	})

	It("write colored debug output when log level is DEBUG and color is true", func() {
		buf := bytes.Buffer{}

		logger := colorlogger.New(colorlogger.DEBUG, true, &buf)

		message := "This is a test"

		logger.Printf(message)
		Expect(buf.String()).To(Equal("\033[32mdebug:\033[0m " + message + "\n"))
	})
})
