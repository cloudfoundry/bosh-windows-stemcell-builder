#!/usr/bin/env bash
set -eu -o pipefail

# install needed dependencies so that this task can be run on a stock ubuntu image
apt-get update -y
apt-get install -y curl jq

bosh_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest \
                | jq -r '.assets[] | select(.name | contains ("linux-amd64")) | .browser_download_url')"
meta4_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/dpb587/metalink/releases/latest \
                | jq -r '.assets[] | select(.name | match("meta4-[0-9]+.[0-9]+.[0-9]+-linux-amd64")) | .browser_download_url')"
yq_cli_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/mikefarah/yq/releases/latest \
                | jq -r '.assets[] | select(.name | endswith ("linux_amd64")) | .browser_download_url')"
ruby_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/postmodern/ruby-install/releases/latest \
                    | jq -r '.assets[] | select(.name | endswith ("tar.gz")) | .browser_download_url')"
golangci_lint_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/golangci/golangci-lint/releases/latest \
                    | jq -r '.assets[] | select(.name | match("golangci-lint-[0-9]+.[0-9]+.[0-9]+-linux-amd64.tar.gz")) | .browser_download_url')"

# TODO: figure out why v0.50.0 fails with 'govc: A specified parameter was not correct: spec.identity.userData.fullName'
govc_install_url="https://github.com/vmware/govmomi/releases/download/v0.29.0/govc_Linux_x86_64.tar.gz"
#govc_install_url="$(curl -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -s https://api.github.com/repos/vmware/govmomi/releases/latest \
#                    | jq -r '.assets[] | select(.name | match("govc_Linux_x86_64.tar.gz")) | .browser_download_url')"

gem_home="/usr/local/bundle"
ruby_version="$(cat bosh-windows-stemcell-builder-ci/.ruby-version)"

cat << JSON > docker-build-args/docker-build-args.json
{
  "BOSH_CLI_URL": "${bosh_cli_url}",
  "META4_CLI_URL": "${meta4_cli_url}",
  "GOLANGCI_LINT_INSTALL_URL":"${golangci_lint_install_url}",
  "GOVC_INSTALL_URL":"${govc_install_url}",
  "YQ_CLI_URL": "${yq_cli_url}",

  "RUBY_INSTALL_URL": "${ruby_install_url}",
  "RUBY_VERSION": "${ruby_version}",
  "GEM_HOME": "${gem_home}"
}
JSON

cat docker-build-args/docker-build-args.json
