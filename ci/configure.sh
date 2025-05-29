#!/usr/bin/env bash
set -eu -o pipefail

REPO_ROOT="$( cd "$( dirname "${0}" )/.." && pwd )"

fly="${FLY_CLI:-fly}"
concourse_target="${CONCOURSE_TARGET:-bosh-ecosystem}"

until "${fly}" -t "${concourse_target}" status; do
  "${fly}" -t "${concourse_target}" login
  sleep 1
done

"${fly}" -t "${concourse_target}" set-pipeline \
  -p "stemcells-windows-2019" \
  -c "${REPO_ROOT}/ci/pipelines/stemcells-windows.yml" \
  -l "${REPO_ROOT}/ci/pipelines/vars.yml"
