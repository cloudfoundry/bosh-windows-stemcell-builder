#!/bin/bash

set -e

export GOPATH="$PWD"
export PATH="$PATH:$GOPATH/bin"

if [ -n "$IAAS" ]; then
	source "$GOPATH/src/github.com/cloudfoundry-incubator/bosh-windows-acceptance-tests/ci/scripts/init-$IAAS.sh"
fi

go get -u -t "github.com/onsi/ginkgo/..."
go get -u -t "github.com/onsi/gomega/..."
ginkgo -r -v "$GOPATH/src/github.com/cloudfoundry-incubator/bosh-windows-acceptance-tests"
