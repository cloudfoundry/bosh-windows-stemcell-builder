#!/usr/bin/env bash
set -eu -o pipefail
set -x

CONCOURSE_ROOT="$(pwd)"

bosh_agent_resource_dir="${CONCOURSE_ROOT}/${BOSH_AGENT_DIR}"
bosh_agent_resource_version="$(cat "${bosh_agent_resource_dir}/.resource/version")"

zip_output_dir="${CONCOURSE_ROOT}/${ZIP_OUTPUT_DIR:-"stemcell-builder/build"}"

mkdir -p "${zip_output_dir}"

zip_dir="${zip_output_dir}/compiled-agent"
zip_deps_dir="${zip_dir}/deps/"

mkdir -p "${zip_dir}"
mkdir -p "${zip_deps_dir}"

# agent-zip root
cp "${bosh_agent_resource_dir}/bosh-agent-${bosh_agent_resource_version}-windows-amd64.exe" "${zip_dir}/bosh-agent.exe"
# `sha` filename expected by `bosh-windows-stemcell-builder` rake tasks; TODO: reduce coupling
cp "${bosh_agent_resource_dir}/git-sha-${bosh_agent_resource_version}" "${zip_dir}/sha"
cp "${bosh_agent_resource_dir}/service_wrapper-${bosh_agent_resource_version}.xml" "${zip_dir}/service_wrapper.xml"

cp "${CONCOURSE_ROOT}"/windows-winsw/WinSW.NET461.exe "${zip_dir}/service_wrapper.exe"

# agent-zip deps
cp "${bosh_agent_resource_dir}/bosh-agent-pipe-${bosh_agent_resource_version}-windows-amd64.exe" "${zip_deps_dir}/pipe.exe"

cp "${CONCOURSE_ROOT}"/blobstore-gcs-cli/bosh-gcscli-*.exe "${zip_deps_dir}/bosh-blobstore-gcs.exe"
cp "${CONCOURSE_ROOT}"/blobstore-dav-cli/davcli-*.exe "${zip_deps_dir}/bosh-blobstore-dav.exe"
cp "${CONCOURSE_ROOT}"/blobstore-s3-cli/s3cli-*.exe "${zip_deps_dir}/bosh-blobstore-s3.exe"
cp "${CONCOURSE_ROOT}"/windows-bsdtar/tar-*.exe "${zip_deps_dir}/tar.exe"
cp "${CONCOURSE_ROOT}"/windows-winsw/WinSW.NET461.exe "${zip_deps_dir}/job-service-wrapper.exe"

pushd "${zip_dir}"
  zip -r "${zip_output_dir}/agent.zip" ./*
popd
