#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

VERSION=$(cat version/version)
OUTPUT_DIR="${ROOT_DIR}/output"

cp "${ROOT_DIR}"/${STEMCELL_AUTOMATION_ZIP} \
  "${ROOT_DIR}/stemcell-builder/stembuild/assets/StemcellAutomation.zip"

pushd "${ROOT_DIR}/stemcell-builder/stembuild"
  echo '***Building Stembuild***'
  make STEMCELL_VERSION="${VERSION}" stembuild
popd

echo '***Copying stembuild to output directory***'
cp "${ROOT_DIR}/stemcell-builder/stembuild/out/stembuild" \
  "${OUTPUT_DIR}/stembuild-linux-x86_64-${VERSION}"
