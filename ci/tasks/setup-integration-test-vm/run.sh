#!/usr/bin/env bash
set -eu -o pipefail

export GOVC_URL="${VCENTER_ADMIN_CREDENTIAL_URL}"

ROOT_DIR=$(pwd)
export OUTPUT_DIR=${ROOT_DIR}/output

CLONE_NAME="${CLONE_PREFIX}-$(date -u +"%Y-%m-%d_%H-%M")"

echo "${CLONE_NAME}" > integration-vm-name/name
echo "Creating VM ${CLONE_NAME}"

govc vm.clone \
  -vm "${BASE_VM_IPATH}" \
  -ds "${CLONE_DATASTORE}" \
  -pool "${CLONE_RESOURCE_POOL}" \
  -folder "${CLONE_FOLDER}" \
  -on=false "${CLONE_NAME}"

echo "Customizing ${CLONE_NAME}"
govc vm.customize \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}" \
  -org "${VM_ORG_NAME}" \
  -username "${VM_USERNAME}" \
  "${VM_CUSTOMIZATION_NAME}"

govc vm.power -on \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}"

echo "Waiting for VM to be configured with IP address..."
SECONDS=0
FOUND_IP_ADDRESS=

while [ -z "$FOUND_IP_ADDRESS" ] || [ "$FOUND_IP_ADDRESS" == "null" ]; do
  VM_INFO=$(govc vm.info -json "${CLONE_FOLDER}"/"${CLONE_NAME}")
  FOUND_IP_ADDRESS=$(echo "${VM_INFO}" | jq -r '.virtualMachines[0].guest.ipAddress')

  echo "Current IP Addresses:"
  echo "${VM_INFO}" | jq -r ".virtualMachines[0].guest.net[0].ipAddress | .[]?"

  if [ ${SECONDS} -gt 600 ] ; then
    exit 1
  fi
  sleep 10
done

echo "Waiting for VM guest customization to complete..."
SECONDS=0
GUEST_CUSTOMIZATION_STATUS=

while [ "$GUEST_CUSTOMIZATION_STATUS" != "TOOLSDEPLOYPKG_SUCCEEDED" ]; do
  GUEST_CUSTOMIZATION_STATUS=$(govc vm.info -json "${CLONE_FOLDER}"/"${CLONE_NAME}" | jq -r '.virtualMachines[0].guest.customizationInfo.customizationStatus')

  if [ ${SECONDS} -gt 600 ] ; then
    exit 1
  fi
  sleep 30
done

echo "Integration VM setup complete"