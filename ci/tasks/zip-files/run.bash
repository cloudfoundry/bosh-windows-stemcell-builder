#!/usr/bin/env bash
set -eu -o pipefail

ROOT_DIR=$(pwd)

REPO_ROOT="${REPO_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"}"
ZIP_FILE_DESTINATION="${ZIP_FILE_DESTINATION:-"${ROOT_DIR}/zip-file/StemcellAutomation-$(date +"%s").zip"}"

BOSH_PSMODULES_ZIP="${BOSH_PSMODULES_ZIP:-"${ROOT_DIR}/psmodules-zip-output/bosh-psmodules.zip"}"
AGENT_ZIP="${AGENT_ZIP:-"${ROOT_DIR}/bosh-agent/agent.zip"}"
DEPS_JSON="${DEPS_JSON:-"${ROOT_DIR}/deps-file/deps.json"}"

TEMP_DIR=$(mktemp -d)
trap 'rm -r "${TEMP_DIR}"' EXIT
stemcell_automation_dir="${TEMP_DIR}/stemcell_automation"
stemcell_automation_zip="${TEMP_DIR}/StemcellAutomation.zip"

mkdir -p "${stemcell_automation_dir}"

declare -a files_to_zip
mapfile -t files_to_zip < <(find "${REPO_ROOT}/stembuild/stemcell-automation" -type f -not -name "*Test*" -name "*.ps*1")
files_to_zip+=("${BOSH_PSMODULES_ZIP}" "${AGENT_ZIP}" "${DEPS_JSON}")

cp "${files_to_zip[@]}" "${stemcell_automation_dir}"

zip -rj "${stemcell_automation_zip}" "${stemcell_automation_dir}"

cp "${stemcell_automation_zip}" "${ZIP_FILE_DESTINATION}"
