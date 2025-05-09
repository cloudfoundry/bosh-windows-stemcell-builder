package remotemanager

import (
	"time"

	"github.com/masterzen/winrm"
)

type WinRMClientFactory struct {
	host     string
	username string
	password string
}

func NewWinRmClientFactory(host, username, password string) *WinRMClientFactory {
	return &WinRMClientFactory{host: host, username: username, password: password}
}

func (f *WinRMClientFactory) Build(timeout time.Duration) (WinRMClient, error) {
	endpoint := winrm.NewEndpoint(f.host, WinRmPort, false, true, nil, nil, nil, timeout)
	params := winrm.NewParameters(
		winrm.DefaultParameters.Timeout,
		winrm.DefaultParameters.Locale,
		winrm.DefaultParameters.EnvelopeSize,
	)
	params.AllowTimeout = true
	client, err := winrm.NewClientWithParameters(endpoint, f.username, f.password, params)
	return client, err
}
