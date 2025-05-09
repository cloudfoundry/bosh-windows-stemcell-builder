#!/usr/bin/env bash
set -eu -o pipefail
set -x

export GOVC_INSECURE=1

echo "Retrieving device info to ensure vm has networking"
if ! govc device.info -vm.ipath=${VM_TO_REVERT} 'ethernet-*' ; then
    echo "No network device present, adding network device to VM"
    govc vm.network.add -vm.ipath=${VM_TO_REVERT} -net="internal-network" -net.adapter="e1000e"
    govc device.info -vm.ipath=${VM_TO_REVERT} 'ethernet-*'
fi

echo "Reverting ${VM_TO_REVERT} to snapshot ${SNAPSHOT_NAME}"
govc snapshot.revert -s=true -dc=${DATACENTER} -vm=${VM_TO_REVERT} "${SNAPSHOT_NAME}" || true
govc vm.power -dc=${DATACENTER} -on=true ${VM_TO_REVERT}
