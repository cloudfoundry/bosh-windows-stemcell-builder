#!/usr/bin/env bash
set -euo pipefail

psmodules_sha256="$(shasum -a 256 psmodules-zip-output/bosh-psmodules.zip | cut -d " " -f 1)"
psmodules_version="$(cat version/version)"

agent_sha256="$(shasum -a 256 bosh-agent/agent.zip | cut -d " " -f 1)"
agent_version="$(cat version/version)"

lgpo_sha256="$(shasum -a 256 lgpo-binary/LGPO.zip | cut -d " " -f 1)"
lgpo_version="3"

cat <<EOF > deps-file/deps.json
{
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
