#!/usr/bin/env bash
set -eu -o pipefail

ROOT_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

echo "***Creating GOPATH environment & structure ***"
export GOPATH=$PWD/gopath
export PATH=${GOPATH}/bin:$PATH

# install vcsim for vCenter manager and client contract integration tests
go -C govmomi/vcsim install

pushd "${ROOT_DIR}/stembuild/stembuild"
  echo ***Test Stembuild Code***

  make contract
popd
