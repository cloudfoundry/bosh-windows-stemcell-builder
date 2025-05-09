#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

: "${OPENSSH_ZIP?"Please see README.md on where to obtain this."}"
: "${BOSH_PSMODULES_ZIP?"Please see README.md on where to obtain this."}"
: "${AGENT_ZIP?"Please see README.md on how to construct this."}"
: "${DEPS_JSON?"Please see README.md on how to construct this."}"

TEMP_DIR=$(mktemp -d)

cp "${OPENSSH_ZIP}" "${TEMP_DIR}/OpenSSH-Win64.zip"
cp "${BOSH_PSMODULES_ZIP}" "${TEMP_DIR}/bosh-psmodules.zip"
cp "${AGENT_ZIP}" "${TEMP_DIR}/agent.zip"
cp "${DEPS_JSON}" "${TEMP_DIR}/deps.json"
for file in "${REPO_ROOT}"/stembuild/stemcell-automation/*ps1; do
  if ! [[ "${file}" =~ .*\.Tests\.ps1 ]]; then
    cp "${file}" "${TEMP_DIR}"
  fi
done
rm -f "${REPO_ROOT}/stembuild/assets/StemcellAutomation.zip"

zip -rj "${REPO_ROOT}/stembuild/assets/StemcellAutomation.zip" "${TEMP_DIR}"

rm -r "${TEMP_DIR}"
