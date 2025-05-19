package vcenter_manager

import (
	"context"
	"net/url"
	"time"

	"github.com/vmware/govmomi"
	"github.com/vmware/govmomi/find"
	"github.com/vmware/govmomi/session"
	"github.com/vmware/govmomi/vim25"
	"github.com/vmware/govmomi/vim25/soap"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . Vim25ClientCreator
type Vim25ClientCreator interface {
	NewClient(ctx context.Context, rt soap.RoundTripper) (*vim25.Client, error)
}

type ClientCreator struct {
}

func (g *ClientCreator) NewClient(ctx context.Context, rt soap.RoundTripper) (*vim25.Client, error) {

	vimClient, err := vim25.NewClient(ctx, rt)
	if err != nil {
		return nil, err
	}

	return vimClient, nil
}

//counterfeiter:generate . FinderCreator
type FinderCreator interface {
	NewFinder(client *vim25.Client, all bool) *find.Finder
}

type GovmomiFinderCreator struct {
}

func (g *GovmomiFinderCreator) NewFinder(client *vim25.Client, all bool) *find.Finder {
	return find.NewFinder(client, all)
}

type ManagerFactory struct {
	Config FactoryConfig
}

type FactoryConfig struct {
	VCenterServer  string
	Username       string
	Password       string
	ClientCreator  Vim25ClientCreator
	FinderCreator  FinderCreator
	RootCACertPath string
}

func (f *ManagerFactory) SetConfig(config FactoryConfig) {
	f.Config = config
}

func (f *ManagerFactory) VCenterManager(ctx context.Context) (*VCenterManager, error) {

	govmomiClient, err := f.govmomiClient(ctx)
	if err != nil {
		return nil, err
	}

	finder := f.Config.FinderCreator.NewFinder(govmomiClient.Client, false)

	return NewVCenterManager(govmomiClient, govmomiClient.Client, finder, f.Config.Username, f.Config.Password)

}

func (f *ManagerFactory) govmomiClient(ctx context.Context) (*govmomi.Client, error) {

	sc, err := f.soapClient()
	if err != nil {
		return nil, err
	}

	vc, err := f.vimClient(ctx, sc)
	if err != nil {
		return nil, err
	}

	return &govmomi.Client{
		Client:         vc,
		SessionManager: session.NewManager(vc),
	}, nil

}

func (f *ManagerFactory) soapClient() (*soap.Client, error) {
	vCenterURL, err := soap.ParseURL(f.Config.VCenterServer)
	if err != nil {
		return nil, err
	}
	credentials := url.UserPassword(f.Config.Username, f.Config.Password)
	vCenterURL.User = credentials

	soapClient := soap.NewClient(vCenterURL, false)

	if f.Config.RootCACertPath != "" {
		err = soapClient.SetRootCAs(f.Config.RootCACertPath)
		if err != nil {
			return nil, err
		}
	}

	return soapClient, nil
}

func (f *ManagerFactory) vimClient(ctx context.Context, soapClient *soap.Client) (*vim25.Client, error) {
	vimClient, err := f.Config.ClientCreator.NewClient(ctx, soapClient)
	if err != nil {
		return nil, err
	}

	vimClient.RoundTripper = session.KeepAlive(vimClient.RoundTripper, 10*time.Minute)
	return vimClient, nil
}
