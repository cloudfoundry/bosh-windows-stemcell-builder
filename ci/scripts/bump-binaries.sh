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

SAFETY_DAYS=7

get_latest_release_json() {
  local repo=$1
  if command -v gh &> /dev/null; then
    gh api "repos/${repo}/releases/latest"
  else
    curl -s -H "Authorization: token ${GITHUB_TOKEN:-}" "https://api.github.com/repos/${repo}/releases/latest"
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
  
  local release_json
  release_json=$(get_latest_release_json "${repo}")
  
  # 1. Check the Safety Buffer using jq
  local age_days
  age_days=$(echo "${release_json}" | jq -r 'if .published_at then ((now - (.published_at | fromdateiso8601)) / 86400) | floor else -1 end')
  
  if [[ "${age_days}" != "-1" ]] && [[ "${age_days}" -lt "${SAFETY_DAYS}" ]]; then
    echo "  Skipping: Release is only ${age_days} days old (requires ${SAFETY_DAYS} days of safety)."
    return 0
  fi
  
  # 2. Extract the URL
  local url
  url=$(echo "${release_json}" | jq -r ".assets[] | select(.name | test(\"${pattern}\")) | .browser_download_url" | head -n 1)
  
  if [[ -z "${url}" || "${url}" == "null" ]]; then
    echo "Failed to find asset for ${repo} matching ${pattern}" >&2
    return 1
  fi
  
  # 3. Compare with current version
  local current_url
  current_url=$(jq -r ".${key}.url" < "${DEPS_FILE}")
  
  if [[ "${url}" == "${current_url}" ]]; then
    echo "  Already up to date."
    return 0
  fi
  
  # 4. Apply the update
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
