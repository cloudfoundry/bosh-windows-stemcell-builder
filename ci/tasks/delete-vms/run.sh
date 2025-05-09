#!/usr/bin/env bash
set -eu -o pipefail

pushd bosh-windows-stemcell-builder-ci/ci/tasks/delete-vms
  bundle install
  bundle exec ruby delete-vms.rb
popd
