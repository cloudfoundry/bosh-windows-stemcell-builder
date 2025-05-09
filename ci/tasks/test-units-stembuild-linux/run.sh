#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

VERSION=$(cat version/version)
STEMBUILD_DIR="${ROOT_DIR}/stembuild/stembuild"
OUTPUT_DIR="${ROOT_DIR}/output"

echo '***Installing VMWare OVF Tools***'
chmod +x ./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle
./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required

pushd "${STEMBUILD_DIR}"
  echo '***Test Stembuild Code***'
  make units
popd
