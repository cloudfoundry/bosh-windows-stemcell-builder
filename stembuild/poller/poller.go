package poller

import (
	"time"
)

type Poller struct{}

func (p *Poller) Poll(duration time.Duration, loopFunc func() (bool, error)) error {
	poll := true
	for poll {
		time.Sleep(duration)
		out, err := loopFunc()
		if err != nil {
			return err
		}
		poll = !out
	}
	return nil
}
