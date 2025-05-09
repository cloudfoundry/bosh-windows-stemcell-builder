#!/usr/bin/env bash
set -eu -o pipefail

ROOT_DIR=$(pwd)

export OPENSSH_ZIP=open-ssh/OpenSSH-Win64.zip
export BOSH_PSMODULES_ZIP=psmodules-zip-output/bosh-psmodules.zip
export AGENT_ZIP=bosh-agent/agent.zip
export DEPS_JSON=deps-file/deps.json

"${ROOT_DIR}/stembuild/bin/build-stemcell-automation-zip.sh"

cp "${ROOT_DIR}/stembuild/stembuild/assets/StemcellAutomation.zip" \
  "zip-file/StemcellAutomation-$(date +"%s").zip"
