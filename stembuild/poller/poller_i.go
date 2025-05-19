package poller

import (
	"time"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . PollerI
type PollerI interface {
	Poll(duration time.Duration, loopFunc func() (bool, error)) error
}
