#!/bin/bash

set -eu -o pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

(
  set -eu -o pipefail
  cd "${ROOT_DIR}"

  go test -c
)
