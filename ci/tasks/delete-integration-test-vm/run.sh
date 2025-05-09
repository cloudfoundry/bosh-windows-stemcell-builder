#!/usr/bin/env bash

set -u # Do not set 'e' as govc will fail if the vm has already been cleaned up

if [[ ! -d integration-vm-name ]]; then
  echo "integration vm information not provided as an input"
  echo "continuing (by doing nothing), so we clear IP locks in the next step"
  echo "please see your previous tasks if this is unexpected"
  exit 0
fi

export VM_NAME=$(cat integration-vm-name/name)
export VM_IPATH="${CLONE_FOLDER}/${VM_NAME}"

govc vm.destroy -u "${VCENTER_ADMIN_CREDENTIAL_URL}" -vm.ipath "${VM_IPATH}"

exit 0
