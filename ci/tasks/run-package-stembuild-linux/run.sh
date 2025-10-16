#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR="$( pwd )"
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

build_version="$(cat build-number/number)"
build_patch="$(echo "${build_version}" | cut -d . -f3,4)"
build_date="$(date -u +"%Y%m%d%H%M")"
patch_version="${build_patch}${build_date}"

ca_cert_file="${ROOT_DIR}/vcenter_ca.crt"
echo "${VCENTER_CA_CERT}" > "${ca_cert_file}"

cp stembuild-untested-linux/stembuild* "${ROOT_DIR}/stembuild"
chmod 500 "${ROOT_DIR}/stembuild"

./stembuild -debug package \
  -vcenter-url "${VCENTER_BASE_URL}" \
    -vcenter-username "${VCENTER_USERNAME}" \
    -vcenter-password "${VCENTER_PASSWORD}" \
  -vcenter-ca-certs "${ca_cert_file}" \
  -vm-inventory-path "${VCENTER_VM_FOLDER}/${STEMBUILD_BASE_VM_NAME}" \
  -patch-version "${patch_version}"

mv *.tgz stembuild-built-stemcell
