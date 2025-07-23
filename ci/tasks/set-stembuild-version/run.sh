#!/usr/bin/env bash
set -euo pipefail
set -x

version="$(cut -d '.' -f1-2 < version/version)"
stembuild_untested_dirs=( stembuild-untested-windows stembuild-untested-linux )

for stembuild_untested_dir in "${stembuild_untested_dirs[@]}"; do
    orig_file_name=$(find "${stembuild_untested_dir}" -name stembuild-\* -type f -printf "%f\n")
    new_file_name=$(
      echo "${orig_file_name}" \
      | sed -r "s/[0-9]+\.[0-9]+\.[0-9]+(-build\.[0-9]+)?/${version}/g"
    )

    cp "${stembuild_untested_dir}/${orig_file_name}" "final-stembuilds/${new_file_name}"
done

echo "${version}" > final-stembuilds/tag
