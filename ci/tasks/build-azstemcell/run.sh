#!/usr/bin/env bash
set -eu -o pipefail

CONCOURSE_ROOT="$(pwd)"

cd bosh-windows-stemcell-builder-ci/ci/azstemcell

go build -o "${CONCOURSE_ROOT}/azstemcell-binary-out/azstemcell"
