package poller_test

import (
	"errors"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/poller"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Poller", func() {
	Describe("Poll", func() {
		It("calls the polling function once per duration until the function returns true", func() {
			poller := poller.Poller{}
			callCount := 0
			startTime := time.Now()
			period := 500 * time.Millisecond
			Expect(poller.Poll(period, func() (bool, error) {
				callCount++
				Expect(startTime.Add(time.Duration(callCount) * period)).To(BeTemporally("~", time.Now(), 200*time.Millisecond))
				return callCount == 3, nil
			})).To(Succeed())

			Expect(callCount).To(Equal(3))
		})
		It("returns an error when polling fails", func() {
			poller := poller.Poller{}
			Expect(poller.Poll(0*time.Second, func() (bool, error) {
				return true, errors.New("polling is hard :(")
			})).To(MatchError("polling is hard :("))
		})
	})
})
