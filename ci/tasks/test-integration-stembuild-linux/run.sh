#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

export OUTPUT_DIR="${ROOT_DIR}/output"

VERSION=$(cat version/version)
export STEMBUILD_VERSION="${VERSION}"

source "bosh-windows-stemcell-builder-ci/ci/common-scripts/update_nimbus_urls_and_cert.sh"

echo '---> Install VMWare OVF Tools'
chmod +x "${ROOT_DIR}/ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle"
"${ROOT_DIR}/ovftool/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle" --eulas-agreed --required

export TARGET_VM_IP
export VM_NAME
VM_NAME=$(cat integration-vm-name/name)
echo "Using VM @ IPAddr: ${VM_NAME}@${TARGET_VM_IP}"

pushd "${ROOT_DIR}/stemcell-builder/stembuild"
  echo '***Test Stembuild Code***'
  make integration
popd
