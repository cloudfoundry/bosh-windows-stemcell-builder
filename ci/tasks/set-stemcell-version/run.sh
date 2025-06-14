#!/usr/bin/env bash
set -euo pipefail

version="$(cat version/version)"

pushd bosh-windows-stemcell
  echo "BEGIN Files in $(pwd)"
  ls -al
  echo "^^END Files in $(pwd)"

  orig_file_name="$(ls ./*.tgz)"
  new_file_name=$(
    echo "${orig_file_name}" \
    | sed -r "s/[0-9]+\.[0-9]+\.[0-9]+(-build\.[0-9]+)?/${version}/g"
  )

  tar -xvf "${orig_file_name}"
  yq -i ".version = \"${version}\"" stemcell.MF

  tar -zcvf "${new_file_name}" image stemcell.MF
popd

cp "bosh-windows-stemcell/${new_file_name}" \
  "version/version" \
  final-stemcell/
