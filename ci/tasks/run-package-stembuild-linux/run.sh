#!/usr/bin/env bash
set -eu -o pipefail
set -x

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT

pushd stembuild-untested-linux
  mv stembuild* stembuild
popd
mv stembuild-untested-linux/stembuild .

chmod 500 stembuild

version="$(cat build-number/number)"
stemcell_build_number="$(date -u +"%Y%m%d%H%M")"
IFS='.' read -r -a array <<< "$version"
patch_version="${array[2]}.${array[3]}${stemcell_build_number}"

./stembuild package \
  -vcenter-ca-certs ca.crt \
  -vcenter-url "${VCENTER_BASE_URL}" \
  -vcenter-username "${VCENTER_USERNAME}" \
  -vcenter-password "${VCENTER_PASSWORD}" \
  -vm-inventory-path "${VCENTER_VM_FOLDER}/${STEMBUILD_BASE_VM_NAME}" \
  -patch-version "${patch_version}"

mv *.tgz stembuild-built-stemcell

