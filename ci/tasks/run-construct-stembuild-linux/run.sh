#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR="$( pwd )"
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

cp lgpo-binary/LGPO*.zip "${ROOT_DIR}/LGPO.zip"

ca_cert_file="${ROOT_DIR}/vcenter_ca.crt"
echo "${VCENTER_CA_CERT}" > "${ca_cert_file}"

cp stembuild-untested-linux/stembuild* "${ROOT_DIR}/stembuild"
chmod 500 "${ROOT_DIR}/stembuild"

./stembuild -debug construct \
  -vcenter-url "${VCENTER_BASE_URL}" \
    -vcenter-username "${VCENTER_USERNAME}" \
    -vcenter-password "${VCENTER_PASSWORD}" \
  -vcenter-ca-certs "${ca_cert_file}" \
  -vm-inventory-path "${VCENTER_VM_FOLDER}/${STEMBUILD_BASE_VM_NAME}" \
  -vm-ip "${STEMBUILD_BASE_VM_IP}" \
    -vm-username "${STEMBUILD_BASE_VM_USERNAME}" \
    -vm-password "${STEMBUILD_BASE_VM_PASSWORD}" \
  -setup-arg FailOnInstallWUCerts
