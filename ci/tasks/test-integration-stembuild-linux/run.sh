#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

VERSION=$(cat version/version)
STEMBUILD_DIR="${ROOT_DIR}/stembuild/stembuild"
OUTPUT_DIR="${ROOT_DIR}/output"

source "bosh-windows-stemcell-builder-ci/ci/common-scripts/update_nimbus_urls_and_cert.sh"

echo '***Installing VMWare OVF Tools***'
chmod +x ./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle
./ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required

export BOSH_PSMODULES_REPO="${ROOT_DIR}/bosh-psmodules-repo"
export STEMBUILD_VERSION
export TARGET_VM_IP
export VM_NAME

STEMBUILD_VERSION=$(cat version/version)
TARGET_VM_IP=$(cat nimbus-ips/name)
VM_NAME=$(cat integration-vm-name/name)

echo "Using Existing VM IP/Name: ${TARGET_VM_IP}/${VM_NAME}"

pushd "${STEMBUILD_DIR}"
  echo '***Test Stembuild Code***'
  make integration
popd
