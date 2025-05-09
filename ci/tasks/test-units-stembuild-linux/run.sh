#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

VERSION=$(cat version/version)
OUTPUT_DIR="${ROOT_DIR}/output"

echo '***Installing VMWare OVF Tools***'
chmod +x ./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle
./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required

pushd "${ROOT_DIR}/stemcell-builder/stembuild"
  echo '***Test Stembuild Code***'
  make units
popd
