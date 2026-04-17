#!/usr/bin/env bash
set -eu -o pipefail

# install needed dependencies so that this task can be run on a stock ubuntu image
apt-get update -y
apt-get install -y ca-certificates curl jq

deps_file="bosh-windows-stemcell-builder-ci/ci/docker/dependencies.json"

bosh_cli_url="$(jq -r '.bosh_cli.url' < "${deps_file}")"
bosh_cli_sha="$(jq -r '.bosh_cli.sha256' < "${deps_file}")"

meta4_cli_url="$(jq -r '.meta4_cli.url' < "${deps_file}")"
meta4_cli_sha="$(jq -r '.meta4_cli.sha256' < "${deps_file}")"

yq_cli_url="$(jq -r '.yq_cli.url' < "${deps_file}")"
yq_cli_sha="$(jq -r '.yq_cli.sha256' < "${deps_file}")"

ruby_install_url="$(jq -r '.ruby_install.url' < "${deps_file}")"
ruby_install_sha="$(jq -r '.ruby_install.sha256' < "${deps_file}")"

golangci_lint_install_url="$(jq -r '.golangci_lint.url' < "${deps_file}")"
golangci_lint_install_sha="$(jq -r '.golangci_lint.sha256' < "${deps_file}")"

govc_install_url="$(jq -r '.govc.url' < "${deps_file}")"
govc_install_sha="$(jq -r '.govc.sha256' < "${deps_file}")"

gem_home="/usr/local/bundle"
ruby_version="$(cat bosh-windows-stemcell-builder-ci/.ruby-version)"

cat << JSON > docker-build-args/docker-build-args.json
{
  "BOSH_CLI_URL": "${bosh_cli_url}",
  "BOSH_CLI_SHA256": "${bosh_cli_sha}",
  "META4_CLI_URL": "${meta4_cli_url}",
  "META4_CLI_SHA256": "${meta4_cli_sha}",
  "GOLANGCI_LINT_INSTALL_URL": "${golangci_lint_install_url}",
  "GOLANGCI_LINT_INSTALL_SHA256": "${golangci_lint_install_sha}",
  "GOVC_INSTALL_URL": "${govc_install_url}",
  "GOVC_INSTALL_SHA256": "${govc_install_sha}",
  "YQ_CLI_URL": "${yq_cli_url}",
  "YQ_CLI_SHA256": "${yq_cli_sha}",

  "RUBY_INSTALL_URL": "${ruby_install_url}",
  "RUBY_INSTALL_SHA256": "${ruby_install_sha}",
  "RUBY_VERSION": "${ruby_version}",
  "GEM_HOME": "${gem_home}"
}
JSON

cat docker-build-args/docker-build-args.json
