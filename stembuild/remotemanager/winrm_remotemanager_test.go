package remotemanager_test

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"

	"github.com/masterzen/winrm"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/ghttp"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager/remotemanagerfakes"
)

func setupTestServer() *Server {
	server := NewServer()

	// winRMClient expects: `//w:Selector[@Name='ShellId']`
	createShellResponse := `<s:Envelope xmlns:s="https://www.w3.org/2003/05/soap-envelope"
	           xmlns:a="https://schemas.xmlsoap.org/ws/2004/08/addressing"
	           xmlns:w="https://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
	 <s:Header>
	   <w:ShellId>153600</w:ShellId>
	 </s:Header>
	 <s:Body/>
	</s:Envelope> `
	server.AppendHandlers(
		CombineHandlers(
			VerifyRequest("POST", "/wsman"),
			VerifyContentType("application/soap+xml;charset=UTF-8"),
			// body contains `<a:Action mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/09/transfer/Create</a:Action>`
			func(w http.ResponseWriter, req *http.Request) {
				body, err := io.ReadAll(req.Body)
				Expect(err).NotTo(HaveOccurred())
				err = req.Body.Close()
				Expect(err).NotTo(HaveOccurred())
				Expect(body).To(MatchRegexp(`http://schemas.xmlsoap.org/ws/2004/09/transfer/Create`))
			},
			RespondWith(http.StatusOK, createShellResponse, http.Header{
				"Content-Type": {"application/soap+xml;charset=UTF-8"},
			}),
		),
	)

	deleteShellResponse := ""
	server.AppendHandlers(
		CombineHandlers(
			VerifyRequest("POST", "/wsman"),
			VerifyContentType("application/soap+xml;charset=UTF-8"),
			// body contains `<a:Action mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete</a:Action>`
			func(w http.ResponseWriter, req *http.Request) {
				body, err := io.ReadAll(req.Body)
				Expect(err).NotTo(HaveOccurred())
				err = req.Body.Close()
				Expect(err).NotTo(HaveOccurred())
				Expect(body).To(MatchRegexp(`http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete`))
			},
			RespondWith(http.StatusOK, deleteShellResponse, http.Header{
				"Content-Type": {"application/soap+xml;charset=UTF-8"},
			}),
		),
	)

	return server
}

var _ = Describe("WinRM RemoteManager", func() {
	Describe("ExecuteCommand", func() {
		var (
			fakeClientFactory *remotemanagerfakes.FakeWinRMClientFactoryI
			fakeClient        *remotemanagerfakes.FakeWinRMClient
		)

		Context("when a command runs successfully", func() {
			BeforeEach(func() {
				fakeClient = &remotemanagerfakes.FakeWinRMClient{}
				fakeClient.RunReturns(0, nil)
				fakeClientFactory = &remotemanagerfakes.FakeWinRMClientFactoryI{}
				fakeClientFactory.BuildReturns(fakeClient, nil)
			})

			It("returns an exit code of 0 and no error", func() {
				remoteManager := remotemanager.NewWinRM("foo", "bar", "baz", fakeClientFactory)
				exitCode, err := remoteManager.ExecuteCommand("foobar")

				Expect(err).NotTo(HaveOccurred())
				Expect(exitCode).To(Equal(0))
			})

		})

		Context("when a command does not run successfully", func() {
			BeforeEach(func() {
				fakeClient = &remotemanagerfakes.FakeWinRMClient{}
				fakeClientFactory = &remotemanagerfakes.FakeWinRMClientFactoryI{}
				fakeClientFactory.BuildReturns(fakeClient, nil)
			})

			Context("when a command returns a nonzero exit code and an error", func() {
				BeforeEach(func() {
					fakeClient.RunReturns(2, errors.New("command error"))
				})

				It("returns the command's nonzero exit code and errors", func() {
					remoteManager := remotemanager.NewWinRM("foo", "bar", "baz", fakeClientFactory)
					exitCode, err := remoteManager.ExecuteCommand("foobar")

					Expect(err).To(HaveOccurred())
					Expect(exitCode).To(Equal(2))
				})
			})

			Context("when a command returns a nonzero exit code but does not error", func() {
				BeforeEach(func() {
					fakeClient.RunReturns(2, nil)
				})

				It("returns the command's nonzero exit code and errors", func() {
					remoteManager := remotemanager.NewWinRM("foo", "bar", "baz", fakeClientFactory)
					exitCode, err := remoteManager.ExecuteCommand("foobar")

					Expect(err).To(HaveOccurred())
					Expect(exitCode).To(Equal(2))
				})
			})

			Context("when a command exits 0 but errors", func() {
				BeforeEach(func() {
					fakeClient.RunReturns(0, errors.New("command error"))
				})

				It("returns the command's exit code and errors", func() {
					remoteManager := remotemanager.NewWinRM("foo", "bar", "baz", fakeClientFactory)
					exitCode, err := remoteManager.ExecuteCommand("foobar")

					Expect(err).To(HaveOccurred())
					Expect(exitCode).To(Equal(0))
				})
			})
		})
	})

	Describe("CanLoginVM", func() {
		var (
			testServer  *Server
			winRMClient remotemanager.WinRMClient
		)

		BeforeEach(func() {
			testServer = setupTestServer()

			testServerURL, err := url.Parse(testServer.URL())
			Expect(err).NotTo(HaveOccurred())
			port, err := strconv.Atoi(testServerURL.Port())
			Expect(err).NotTo(HaveOccurred())

			endpoint := &winrm.Endpoint{
				Host: testServerURL.Hostname(),
				Port: port,
			}
			winRMClient, err = winrm.NewClient(endpoint, "", "")
			Expect(err).NotTo(HaveOccurred())
		})

		AfterEach(func() {
			testServer.Close()
		})

		It("returns nil if shell can be created", func() {
			winRMClientFactory := &remotemanagerfakes.FakeWinRMClientFactoryI{}
			winRMClientFactory.BuildReturns(winRMClient, nil)

			remotemanager := remotemanager.NewWinRM("some-host", "some-user", "some-pass", winRMClientFactory)

			err := remotemanager.CanLoginVM()
			Expect(err).NotTo(HaveOccurred())
		})

		It("returns error if winrmclient cannot be created", func() {
			winRMClientFactory := new(remotemanagerfakes.FakeWinRMClientFactoryI)
			buildErr := errors.New("unable to build a client")
			winRMClientFactory.BuildReturns(nil, buildErr)

			remotemanager := remotemanager.NewWinRM("some-host", "some-user", "some-pass", winRMClientFactory)

			err := remotemanager.CanLoginVM()
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError(fmt.Errorf("failed to create winrm client: %w", buildErr)))
		})

		It("returns error if shell cannot be created", func() {
			winRMClientFactory := new(remotemanagerfakes.FakeWinRMClientFactoryI)
			winRMClient := new(remotemanagerfakes.FakeWinRMClient)
			winRMClientFactory.BuildReturns(winRMClient, nil)

			shellErr := errors.New("some shell creation error")
			winRMClient.CreateShellReturns(nil, shellErr)

			remotemanager := remotemanager.NewWinRM("some-host", "some-user", "some-pass", winRMClientFactory)

			err := remotemanager.CanLoginVM()
			Expect(err).To(HaveOccurred())
			Expect(err).To(MatchError(fmt.Errorf("failed to create winrm shell: %w", shellErr)))
		})
	})
})
