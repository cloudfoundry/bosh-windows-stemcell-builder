package helpers

import (
	"crypto/tls"
	_ "embed"
	"fmt"
	"net/url"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2" //nolint:staticcheck
	. "github.com/onsi/gomega"    //nolint:staticcheck
	"github.com/vmware/govmomi/simulator"
)

//go:embed vcsim-cert
var vcsimCert []byte

//go:embed vcsim-cert.key
var vcsimCertKey []byte

type VcsimServer struct {
	Username        string
	Password        string
	CertificatePath string
	vcsimModel      *simulator.Model
	vcsimServer     *simulator.Server
}

func NewVcsimServer(username string, password string) *VcsimServer {
	GinkgoHelper()
	vcsimServer := &VcsimServer{
		Username: username,
		Password: password,
	}

	return vcsimServer
}

func (h *VcsimServer) Url() string {
	GinkgoHelper()
	return fmt.Sprintf("%s/sdk", h.vcsimServer.URL.Host)
}

func (h *VcsimServer) Start() {
	certDir := GinkgoT().TempDir()
	h.CertificatePath = filepath.Join(certDir, "cert")
	err := os.WriteFile(h.CertificatePath, vcsimCert, 0644)
	Expect(err).NotTo(HaveOccurred())

	certKeyPath := filepath.Join(certDir, "cert.key")
	err = os.WriteFile(certKeyPath, vcsimCertKey, 0644)
	Expect(err).ToNot(HaveOccurred())

	h.vcsimModel = simulator.VPX()
	err = h.vcsimModel.Create()
	Expect(err).ToNot(HaveOccurred())

	h.vcsimModel.Service.RegisterEndpoints = true
	h.vcsimModel.Service.Listen = &url.URL{
		User: url.UserPassword(h.Username, h.Password),
	}

	serverCert, err := tls.LoadX509KeyPair(h.CertificatePath, certKeyPath)
	Expect(err).ToNot(HaveOccurred())
	h.vcsimModel.Service.TLS = &tls.Config{
		Certificates: []tls.Certificate{serverCert},
	}

	h.vcsimServer = h.vcsimModel.Service.NewServer()
}

func (h *VcsimServer) Stop() {
	GinkgoHelper()
	if h.vcsimServer != nil {
		h.vcsimServer.Close()
	}
	if h.vcsimModel != nil {
		h.vcsimModel.Remove()
	}
}
