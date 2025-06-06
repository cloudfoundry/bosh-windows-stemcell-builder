#!/usr/bin/env bash
set -eu -o pipefail
set -x

CONCOURSE_ROOT="$(pwd)"

zip_output_dir="${CONCOURSE_ROOT}/${ZIP_OUTPUT_DIR:-"stemcell-builder/build"}"

mkdir -p "${zip_output_dir}"

pushd "${CONCOURSE_ROOT}/stemcell-builder/modules"
  zip -r "${zip_output_dir}/bosh-psmodules.zip" ./BOSH.*
popd
