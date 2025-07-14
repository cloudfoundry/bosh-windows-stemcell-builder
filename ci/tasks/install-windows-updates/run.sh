#!/bin/bash
set -eu -o pipefail
set -x

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source "${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh"

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT
export GOVC_TLS_CA_CERTS=ca.crt

vm_ipath=${STEMBUILD_CONSTRUCT_TARGET_VM}
vm_username="${VM_USERNAME}"
vm_password="${VM_PASSWORD}"

function start_powershell_command() {
  local powershell_command="${1}"

  echo "Starting '${powershell_command}'" >&2
  pid=$(
    govc guest.start \
      -vm.ipath="${vm_ipath}" \
      -l="${vm_username}:${vm_password}" \
      "\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe" \
      "${powershell_command}"
    )

  if [ -z "${pid}" ]; then
    echo "No PID returned when invoking '${powershell_command}'" >&2
  fi

  echo "${pid}"
}

function get_powershell_pid_exit_code() {
  local powershell_pid="${1}"

  echo "Getting exit code for ${powershell_pid}" >&2
  # -X blocks until the guest process exits
  govc guest.ps \
    -vm.ipath="${vm_ipath}" \
    -l="${vm_username}:${vm_password}" \
    -p="${powershell_pid}" \
    -X -json \
  | jq '.processInfo[0].exitCode'
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
  echo "Exited '${powershell_command}' with exit code '${exit_code}'" >&2
}

function wait_for_vm_to_come_up() {
  result=-1
  set +e
  while [[ result -ne 0 ]]; do
    start_powershell_command Get-ChildItem \\ 2> /dev/null # try to connect
    result=$?
    sleep 1
  done
  set -e
}

function get_windows_updates_remaining() {
  # run powershell command that "exits" with the Count returned by Get-WindowsUpdate
  get_update_count_pid="$(start_powershell_command "exit (([array](Get-WindowsUpdate)).Count)")"

  get_powershell_pid_exit_code "${get_update_count_pid}"
}

wait_for_vm_to_come_up

# get wu-install /wu-update set up to work on the vm...
run_powershell_command_with_logging 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
run_powershell_command_with_logging 'Install-Module -Name PSWindowsUpdate -MinimumVersion 2.1.0.1 -Force'

echo "getting update count exit code via guest.ps"
updates_remaining=$(get_windows_updates_remaining)

echo "Windows Updates to install: ${updates_remaining}"
while [[ updates_remaining -ne 0 ]]; do
  set +e # ignore unreachable agent if the vm just went down for reboot
  run_powershell_command_with_logging "Install-WindowsUpdate -AcceptAll -AutoReboot"
  set -e
  echo "Install-WU done"

  # wait for VM to go down and poll for connectivity
  echo "Waiting for VM to come back after reboot, if necessary..."
  sleep 60
  wait_for_vm_to_come_up

  echo "VM reachable"
  updates_remaining=
  while [[ -z "${updates_remaining}" ]] ; do
    echo "Trying to discover how many updates remain..."
    set +e # ignore failures here since the vmware tools agent may be down while updates are being applied
    updates_remaining=$(get_windows_updates_remaining)
    set -e
  done
  echo "Updates remaining: ${updates_remaining}"
done

remote_hotfix_log_path="C:\\hotfix.log"

run_powershell_command_with_logging "Get-Hotfix > ${remote_hotfix_log_path}"

download_remote_file "${remote_hotfix_log_path}" hotfix-log/hotfixes.log

run_powershell_command_with_logging "Dism.exe /online /Cleanup-Image /StartComponentCleanup"
