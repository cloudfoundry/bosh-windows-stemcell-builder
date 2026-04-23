#!/bin/bash
set -eu -o pipefail
set -x

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT
export GOVC_TLS_CA_CERTS=ca.crt

vm_username="${VM_USERNAME}"
vm_password="${VM_PASSWORD}"

vm_ipath=${STEMBUILD_CONSTRUCT_TARGET_VM}
powershell_exe="\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"

function start_powershell_command() {
  local powershell_command="${1}"

  echo "Starting '${powershell_command}'" >&2
  govc guest.start \
    -vm.ipath="${vm_ipath}" \
    -l="${vm_username}:${vm_password}" \
    "${powershell_exe}" \
    "${powershell_command}"
}

function get_powershell_pid_exit_code() {
  local powershell_pid="${1}"

  if [[ -z "${powershell_pid}" ]]; then
    echo "Provide PID was blank: '${powershell_pid}" >&2
  else
    echo "Getting exit code for '${powershell_pid}'" >&2
    # -X blocks until the guest process exits
    json_out=$(
      govc guest.ps \
      -vm.ipath="${vm_ipath}" \
      -l="${vm_username}:${vm_password}" \
      -X -json \
      -p="${powershell_pid}"
    )
    echo "JSON response for 'guest.ps': ${json_out}" >&2
    echo "${json_out}" | jq '.processInfo[0].exitCode'
  fi
}

function download_remote_file() {
  local remote_path="${1}"
  local local_path="${2}"

  govc guest.download \
    -l "${vm_username}:${vm_password}" \
    -vm="${vm_ipath}" \
    "${remote_path}" "${local_path}"
}

function run_powershell_command_with_logging() {
  local powershell_command="${1}"

  pid=$(start_powershell_command "${powershell_command}")
  echo "Started '${powershell_command}' with pid '${pid}'" >&2

  exit_code=$(get_powershell_pid_exit_code "${pid}")
  echo "Finished '${powershell_command}' with exit code '${exit_code}'" >&2
}

function wait_for_vm_to_come_up() {
  echo "Starting VM check" >&2
  count=0
  result=-1
  while [[ result -ne 0 ]]; do
    set +e
    echo "Checking VM: ${count}" >&2
    count=$((count+1))
    start_powershell_command Get-ChildItem
    result=$?
    set -e
    sleep 5
  done
  echo "Finished VM check" >&2
}

function get_windows_updates_remaining() {
  echo "Checking for updates remaining (via exit code of 'guest.ps')..." >&2
  # run powershell command that "exits" with the Count returned by Get-WindowsUpdate
  get_update_count_pid="$(start_powershell_command "exit (([array](Get-WindowsUpdate)).Count)")"

  exit_code=$(get_powershell_pid_exit_code "${get_update_count_pid}")
  echo "Checking for updates remaining (via exit code of 'guest.ps') returned '${exit_code}'" >&2

  if [[ "${exit_code}" == "null" ]]; then
    echo "Checking for updates remaining (via 'guest.run')..." >&2
    raw_exit_code=$(
      govc guest.run \
        -vm.ipath="${vm_ipath}" \
        -l="${vm_username}:${vm_password}" \
        "${powershell_exe}" \
        "(Get-WindowsUpdate).Count"
    )
    exit_code="${raw_exit_code/$'\r'/}"
    echo "Checking for updates remaining (via 'guest.run') returned '${exit_code}'" >&2
  fi

  echo "${exit_code}"
}

wait_for_vm_to_come_up

# get wu-install /wu-update set up to work on the vm...
run_powershell_command_with_logging 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
run_powershell_command_with_logging 'Install-Module -Name PSWindowsUpdate -MinimumVersion 2.1.0.1 -Force'

updates_remaining=$(get_windows_updates_remaining)
echo "Initial Windows Updates to install: ${updates_remaining}" >&2

# TODO: rewrite as a single loop:
# install updates
# wait for VM to reboot
# wait for vmware tools to be available
# (re)get updates-remaining
# => if remaining == 0; break

while [[ ${updates_remaining} -ne 0 ]]; do
  set +e # ignore unreachable agent if the vm just went down for reboot
  run_powershell_command_with_logging "Install-WindowsUpdate -AcceptAll -AutoReboot"
  set -e

  wait_for_vm_to_come_up

  updates_remaining="checking-for-update-count"
  until [[ "${updates_remaining}" =~ ^[0-9]+$ ]] ; do
    set +e # ignore failures here since the vmware tools agent may be down while updates are being applied
    updates_remaining=$(get_windows_updates_remaining)
    set -e
  done
  echo "Remaining Windows Updates to install: ${updates_remaining}" >&2
done

remote_hotfix_log_path="C:\\hotfix.log"

run_powershell_command_with_logging "Get-Hotfix | Out-File -FilePath ${remote_hotfix_log_path} -Encoding utf8"

download_remote_file "${remote_hotfix_log_path}" hotfix-log/hotfixes.log

dism_cmd="Dism.exe /online /Cleanup-Image /StartComponentCleanup"
echo "Running: ${dism_cmd}" >&2
# not using `run_powershell_command_with_logging`, vmware tools may be stopped before pid can be fetched
start_powershell_command "${dism_cmd}"
