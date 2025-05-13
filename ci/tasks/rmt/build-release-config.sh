#!/usr/bin/env bash
set -eu -o pipefail
set -x

ROOT_DIR=$(pwd)
version=$( cat version/version | cut -d '.' -f1-2 )

docs_link="https://docs.vmware.com/en/Stemcells-for-VMware-Tanzu/services/release-notes/windows-stemcell-v2019x.html"
today="$(date '+%m/%d/%Y')"

cat <<-EOF >./release-config/release.yml
---
product_slug: ${RELEASE_PRODUCT_SLUG}
title: ${RELEASE_TITLE}
version: ${version}
type: ${RELEASE_TYPE}
status: ${RELEASE_STATUS}
third_party_classification: N
oct_request_id: 3930 # https://docs.google.com/spreadsheets/d/1xLPEyngkFvDnAA3RwMw61V3zjNF2YKxTiF_VcRweY2g/
docs_link: "${docs_link}"
ga_date_mm/dd/yyyy: ${today}
end_of_support_date_mm/dd/yyyy: ${RELEASE_END_OF_SUPPORT}
upgrade_specifiers:
- specifier: ${RELEASE_UPGRADE_SPECIFIER}
EOF

declare -A iaases
iaases=(
  ["aws"]="AWS"
  ["gcp"]="GCP"
  ["azure"]="Azure"
)

printf 'files:\n' >> ./release-config/release.yml
for iaas in "${!iaases[@]}"; do
  stemcell_dir="${iaas}-stemcell-final"
  cp "${stemcell_dir}"/*.tgz release-files/
  cat <<EOF >>./release-config/release.yml
- file: "../release-files/$(basename "${stemcell_dir}"/*.tgz)"
  description: "${iaases[$iaas]} light Stemcell"
EOF
done

declare -A stembuilders
stembuilders=(
  ["linux"]="Linux"
  ["windows"]="Windows"
)

for os in "${!stembuilders[@]}"; do
  cp final-stembuilds/stembuild-${os}* release-files/
  cat <<EOF >>./release-config/release.yml
- file: "../release-files/$(basename final-stembuilds/stembuild-${os}*)"
  description: "vSphere Stembuild CLI - ${stembuilders[$os]}"
EOF
done

cp license-file/*.txt release-files/
cat <<EOF >>./release-config/release.yml
- file: "../release-files/$(basename "license-file"/*.txt)"
  description: "Stemcells for PCF (Windows) License"
EOF

echo "RMT release file:"
cat release-config/release.yml