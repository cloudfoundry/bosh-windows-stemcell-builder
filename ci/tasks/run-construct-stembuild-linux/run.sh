#!/usr/bin/env bash
set -ex

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source ${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT

pushd stembuild-untested-linux
  mv stembuild* stembuild
popd
mv stembuild-untested-linux/stembuild .

mv lgpo-binary/LGPO*.zip LGPO.zip

chmod 500 stembuild
./stembuild construct \
  -vcenter-url ${VCENTER_BASE_URL} -vcenter-username ${VCENTER_USERNAME} -vcenter-password ${VCENTER_PASSWORD} \
  -vcenter-ca-certs ca.crt \
  -vm-inventory-path ${VCENTER_VM_FOLDER}/${STEMBUILD_BASE_VM_NAME} \
  -vm-ip ${STEMBUILD_BASE_VM_IP} -vm-username ${STEMBUILD_BASE_VM_USERNAME} -vm-password ${STEMBUILD_BASE_VM_PASSWORD} \
  -setup-arg FailOnInstallWUCerts
