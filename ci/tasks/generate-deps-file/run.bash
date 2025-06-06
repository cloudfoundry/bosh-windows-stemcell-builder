#!/usr/bin/env bash
set -euo pipefail

openssh_win64_sha256="$(shasum -a 256 open-ssh/OpenSSH-Win64.zip | cut -d " " -f 1)"
openssh_win64_version="$(cat open-ssh/version)"

psmodules_sha256="$(shasum -a 256 psmodules-zip-output/bosh-psmodules.zip | cut -d " " -f 1)"
psmodules_version="$(cat version/version)"

agent_sha256="$(shasum -a 256 bosh-agent/agent.zip | cut -d " " -f 1)"
agent_version="$(cat version/version)"

lgpo_sha256="$(shasum -a 256 lgpo-binary/LGPO.zip | cut -d " " -f 1)"
lgpo_version="3"

cat <<EOF > deps-file/deps.json
{
  "OpenSSH-Win64.zip": {
    "sha": "${openssh_win64_sha256}",
    "version": "${openssh_win64_version}"
  },
  "bosh-psmodules.zip": {
    "sha": "${psmodules_sha256}",
    "version": "${psmodules_version}"
  },
  "agent.zip": {
    "sha": "${agent_sha256}",
    "version": "${agent_version}"
  },
  "LGPO.zip": {
    "sha": "${lgpo_sha256}",
    "version": "${lgpo_version}"
  }
}
EOF
