#!/usr/bin/env bash
set -eu -o pipefail

export GOVC_URL="${VCENTER_ADMIN_CREDENTIAL_URL}"

ROOT_DIR=$(pwd)
export OUTPUT_DIR=${ROOT_DIR}/output

VM_IP=$(cat nimbus-ips/name)
CLONE_NAME_PREFIX="construct-${JOB_OS_NAME}-integration-ci-${OS_LINE}"
CLONE_NAME_SUFFIX=$(echo "${VM_IP}" | cut -d . -f 4)
CLONE_NAME=${CLONE_NAME_PREFIX}${CLONE_NAME_SUFFIX}

export VM_IP
export CLONE_NAME_PREFIX
export CLONE_NAME_SUFFIX
export CLONE_NAME

echo "${CLONE_NAME}" > integration-vm-name/name
echo "Creating VM ${CLONE_NAME} with IP: ${VM_IP}"

govc vm.clone \
  -vm "${BASE_VM_IPATH}" \
  -ds "${CLONE_DATASTORE}" \
  -pool "${CLONE_RESOURCE_POOL}" \
  -folder "${CLONE_FOLDER}" \
  -on=false "${CLONE_NAME}"

govc vm.customize \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}" \
  -ip "${VM_IP}" "${VM_CUSTOMIZATION_NAME}"

govc vm.power -on \
  -vm.ipath "${CLONE_FOLDER}"/"${CLONE_NAME}"

echo Waiting for VM to be configured with expected IP address...
SECONDS=0
FOUND_IP_ADDRESS=

while [ "${VM_IP}" != "${FOUND_IP_ADDRESS}" ]; do
	sleep 10
	VM_INFO=$(govc vm.info -json "${CLONE_FOLDER}"/"${CLONE_NAME}")

	FOUND_IP_ADDRESS=$(echo "${VM_INFO}" |
	    jq -r ".VirtualMachines[0].Guest.Net[0].IpAddress | .[]? |select(. == \"${VM_IP}\")")

    echo "Current IP Addresses:"
	echo "${VM_INFO}" | jq -r ".VirtualMachines[0].Guest.Net[0].IpAddress | .[]?"

	if [ ${SECONDS} -gt 600 ] ; then
		exit 1
	fi
done
