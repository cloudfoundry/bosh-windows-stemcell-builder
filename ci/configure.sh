#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${0}" )/.." && pwd )"

if [ "$#" == 0 ]; then
  mapfile -t available_pipelines < <(find "${REPO_ROOT}/ci/pipelines" -type f -name '*.yml' -depth 1 | sort)

  i=1
  echo "Choose a pipeline to configure:"
  for pipeline in "${available_pipelines[@]}"; do
    printf "%4s. $(basename "${pipeline}" '.yml')\n" "${i}"
    i=$((i + 1))
  done
  read -rp "pipeline: " pipeline_index
  echo ""

  pipeline_name="$(basename "${available_pipelines[(pipeline_index-1)]}" .yml)"
elif [ "$#" == 1 ]; then
  # Allow just pipeline name or path to yml file
  pipeline_name="$(basename "${1}" .yml)"
else
  echo "Usage: configure.sh [PIPELINE_NAME_OR_FILE]"
  exit 1
fi

echo "Configuring ${pipeline_name}..."

fly="${FLY_CLI:-fly}"
concourse_target="${CONCOURSE_TARGET:-bosh-ecosystem}"

until "${fly}" -t "${concourse_target}" status;do
  "${fly}" -t "${concourse_target}" login
  sleep 1
done

if [ -d  "${REPO_ROOT}/ci/pipelines/${pipeline_name}" ]; then
  pipeline_file_path="${REPO_ROOT}/ci/pipelines/${pipeline_name}"
else
  pipeline_file_path="${REPO_ROOT}/ci/pipelines/${pipeline_name}.yml"
fi

"${fly}" -t "${concourse_target}" set-pipeline \
  -p "${pipeline_name}" \
  -c <( \
        bosh int "${pipeline_file_path}" \
            -l "${REPO_ROOT}/ci/pipelines/vars/2019-vars.yml" \
    ) \
  -l "${REPO_ROOT}/ci/pipelines/vars/vars.yml"
