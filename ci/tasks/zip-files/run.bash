#!/usr/bin/env bash
set -eu -o pipefail

ROOT_DIR=$(pwd)
STEMBUILD_DIR="${ROOT_DIR}/stembuild/stembuild"

OPENSSH_ZIP=open-ssh/OpenSSH-Win64.zip \
BOSH_PSMODULES_ZIP=bosh-psmodules/bosh-psmodules.zip \
AGENT_ZIP=bosh-agent/agent.zip \
DEPS_JSON=deps-file/deps.json \
"${ROOT_DIR}/stembuild/bin/build-stemcell-automation-zip.sh"

cp "${STEMBUILD_DIR}/assets/StemcellAutomation.zip" "zip-file/StemcellAutomation-$(date +"%s").zip"
