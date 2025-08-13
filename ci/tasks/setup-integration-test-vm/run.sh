#!/usr/bin/env bash
set -eu -o pipefail

export GOVC_URL="${VCENTER_ADMIN_CREDENTIAL_URL}"

ROOT_DIR=$(pwd)
export OUTPUT_DIR=${ROOT_DIR}/output

VM_IP=$(cat nimbus-ips/name)

CLONE_NAME="stembuild-${JOB_OS_NAME}-${OS_LINE}-${VM_IP}"
echo "${CLONE_NAME}" > integration-vm-name/name

echo "Cloning ${BASE_VM_IPATH} to ${CLONE_NAME}"
govc vm.clone \
  -vm "${BASE_VM_IPATH}" \
  -ds "${CLONE_DATASTORE}" \
  -pool "${CLONE_RESOURCE_POOL}" \
  -folder "${CLONE_FOLDER}" \
  -on=false "${CLONE_NAME}"

echo "Customizing ${CLONE_NAME}"
govc vm.customize \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}" \
  -ip "${VM_IP}" \
  -org "${VM_ORG_NAME}" \
  -username "${VM_USERNAME}" \
  "${VM_CUSTOMIZATION_NAME}"

govc vm.power -on \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}"

echo "Waiting 10 min for ${CLONE_NAME} to be configured with ${VM_IP}"
SECONDS=0
FOUND_IP_ADDRESS=

while [ "${VM_IP}" != "${FOUND_IP_ADDRESS}" ]; do
	sleep 10
	VM_INFO=$(govc vm.info -json "${CLONE_FOLDER}"/"${CLONE_NAME}")

	FOUND_IP_ADDRESS=$(echo "${VM_INFO}" |
	    jq -r ".virtualMachines[0].guest.net[0].ipAddress | .[]? |select(. == \"${VM_IP}\")")

  echo "Current IP Addresses:"
	echo "${VM_INFO}" | jq -r ".virtualMachines[0].guest.net[0].ipAddress | .[]?"

	if [ ${SECONDS} -gt 600 ] ; then
		exit 1
	fi
done
