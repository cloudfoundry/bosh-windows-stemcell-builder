#!/usr/bin/env bash
set -eu -o pipefail
set -x

export GOVC_INSECURE=1

echo "Snapshotting ${VM_TO_SNAPSHOT} to snapshot ${SNAPSHOT_NAME}"
govc snapshot.remove -dc=${DATACENTER} -vm=${VM_TO_SNAPSHOT} "${SNAPSHOT_NAME}" || true
govc snapshot.create -m=true -dc=${DATACENTER} -vm=${VM_TO_SNAPSHOT} "${SNAPSHOT_NAME}"
