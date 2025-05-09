#!/usr/bin/env bash

set -euo pipefail

cat <<EOF > deps-file/deps.json
{
  "OpenSSH-Win64.zip": {
    "sha": "$(shasum -a 256 open-ssh/OpenSSH-Win64.zip | cut -d " " -f 1)",
    "version": "$(cat open-ssh/version)"
  },
  "bosh-psmodules.zip": {
    "sha": "$(shasum -a 256 bosh-psmodules/bosh-psmodules.zip | cut -d " " -f 1)",
    "version": "$(cat version/version)"
  },
  "agent.zip": {
    "sha": "$(shasum -a 256 bosh-agent/agent.zip | cut -d " " -f 1)",
    "version": "$(cat version/version)"
  },
  "LGPO.zip": {
    "sha": "$(shasum -a 256 lgpo-binary/LGPO.zip | cut -d " " -f 1)",
    "version": "3"
  }
}
EOF
