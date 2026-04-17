#!/usr/bin/env bash
set -euo pipefail

# Find the absolute path to the dependencies.json file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_FILE="${SCRIPT_DIR}/../docker/dependencies.json"

TMP_FILE=$(mktemp)
trap 'rm -f "${TMP_FILE}"' EXIT

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

get_latest_asset() {
  local repo=$1
  local pattern=$2
  
  # Use GH CLI if available (handles auth automatically), otherwise fallback to curl
  if command -v gh &> /dev/null; then
    gh api "repos/${repo}/releases/latest" | jq -r ".assets[] | select(.name | test(\"${pattern}\")) | .browser_download_url" | head -n 1
  else
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r ".assets[] | select(.name | test(\"${pattern}\")) | .browser_download_url" | head -n 1
  fi
}

get_sha256() {
  local url=$1
  curl -fsSL "${url}" | sha256sum | awk '{print $1}'
}

update_dep() {
  local key=$1
  local repo=$2
  local pattern=$3
  
  echo "Checking ${repo}..."
  local url
  url=$(get_latest_asset "${repo}" "${pattern}")
  
  if [[ -z "${url}" || "${url}" == "null" ]]; then
    echo "Failed to find asset for ${repo} matching ${pattern}" >&2
    return 1
  fi
  
  local current_url
  current_url=$(jq -r ".${key}.url" < "${DEPS_FILE}")
  
  if [[ "${url}" == "${current_url}" ]]; then
    echo "  Already up to date."
    return 0
  fi
  
  echo "  Found new version: ${url}"
  echo "  Calculating SHA256..."
  local sha
  sha=$(get_sha256 "${url}")
  
  echo "  Updating ${DEPS_FILE}..."
  jq ".${key}.url = \"${url}\" | .${key}.sha256 = \"${sha}\"" "${DEPS_FILE}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${DEPS_FILE}"
  echo "  Done."
}

echo "Bumping binaries in ${DEPS_FILE}..."

update_dep "bosh_cli" "cloudfoundry/bosh-cli" "linux-amd64"
update_dep "meta4_cli" "dpb587/metalink" "meta4-[0-9]+.[0-9]+.[0-9]+-linux-amd64"
update_dep "yq_cli" "mikefarah/yq" "linux_amd64$"
update_dep "ruby_install" "postmodern/ruby-install" "tar.gz$"
update_dep "golangci_lint" "golangci/golangci-lint" "golangci-lint-[0-9]+.[0-9]+.[0-9]+-linux-amd64.tar.gz"
update_dep "govc" "vmware/govmomi" "govc_Linux_x86_64.tar.gz"

echo "All binaries bumped successfully!"
