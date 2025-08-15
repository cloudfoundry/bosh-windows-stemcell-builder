#!/usr/bin/env bash
set -euxo pipefail

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source ${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT

VM_NAME="${VCENTER_VM_FOLDER}/${VM_NAME}"

echo "Fetching IP for VM: $VM_NAME..."

SECONDS=0
VM_IP=

while [ -z "$VM_IP" ]  || [ "$VM_IP" == "null" ]; do
  VM_IP=$(govc vm.info -json "$VM_NAME" | jq -r '.virtualMachines[0].guest.ipAddress')

  if [ ${SECONDS} -gt ${TIMEOUT} ] ; then
     echo "Error: could not retrieve IP address for VM '$VM_NAME' in '$TIMEOUT' seconds."
    exit 1
  fi

  sleep 10
done

echo -n "${VM_IP}" > vm-ip/ip
