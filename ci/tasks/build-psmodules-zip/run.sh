#!/usr/bin/env bash
set -eu -o pipefail
set -x

CONCOURSE_ROOT="$(pwd)"

zip_output_dir="${CONCOURSE_ROOT}/${ZIP_OUTPUT_DIR:-"stemcell-builder/build"}"

mkdir -p "${zip_output_dir}"

bosh_psmodules_dir="${CONCOURSE_ROOT}/${BOSH_PSMODULES_DIR:-"bosh-psmodules-repo"}/modules"

pushd "${bosh_psmodules_dir}"
  zip -r "${zip_output_dir}/bosh-psmodules.zip" ./*
popd
