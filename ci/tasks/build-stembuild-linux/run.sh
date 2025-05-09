#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)

VERSION=$(cat version/version)
STEMBUILD_DIR="${ROOT_DIR}/stembuild/stembuild"
OUTPUT_DIR="${ROOT_DIR}/output"

cp "${ROOT_DIR}"/${STEMCELL_AUTOMATION_ZIP} "${STEMBUILD_DIR}/assets/StemcellAutomation.zip"

pushd "${STEMBUILD_DIR}"
  echo '***Building Stembuild***'
  make \
    STEMCELL_VERSION="${VERSION}" \
    build
popd

echo '***Copying stembuild to output directory***'
cp "${STEMBUILD_DIR}/out/stembuild" "${OUTPUT_DIR}/stembuild-linux-x86_64-${VERSION}"
