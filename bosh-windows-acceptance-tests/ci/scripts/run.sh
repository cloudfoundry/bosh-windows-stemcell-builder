#!/bin/bash

export GOPATH="$PWD/stemcell-builder"
export PATH="$PATH:$GOPATH/bin"

if [ -n "$IAAS" ]; then
	source "$GOPATH/src/github.com/cloudfoundry-incubator/bosh-windows-acceptance-tests/ci/scripts/init-$IAAS.sh"
fi

go get -u -t "github.com/onsi/ginkgo/..."
go get -u -t "github.com/onsi/gomega/..."
ginkgo -r -v "$GOPATH/src/github.com/cloudfoundry-incubator/bosh-windows-acceptance-tests"
GINKGO_EXIT=$?

# Kill any ssh tunnels left by our IAAS specific setup
TUNNEL_PID=$(ps -C ssh -o pid=)
if [ -n "$TUNNEL_PID" ]; then
	kill -9 $TUNNEL_PID
fi

exit $GINKGO_EXIT
