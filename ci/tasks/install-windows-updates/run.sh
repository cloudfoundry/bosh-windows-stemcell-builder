#!/bin/bash

set -eu

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

source ${SCRIPT_DIR}/../../common-scripts/update_nimbus_urls_and_cert.sh

cat > ca.crt <<END_OF_CERT
$VCENTER_CA_CERT
END_OF_CERT
export GOVC_TLS_CA_CERTS=ca.crt

vm_ipath=${STEMBUILD_CONSTRUCT_TARGET_VM}
vm_username=${VM_USERNAME}
vm_password=${VM_PASSWORD}

powershell_exe="\\Windows\\System32\\WindowsPowerShell\\V1.0\\powershell.exe"

govc_pwsh_cmd="govc guest.start -vm.ipath=${vm_ipath} -l=${vm_username}:${vm_password} $powershell_exe"

# get wu-install /wu-update set up to work on the vm...

function wait_for_vm_to_come_up() {
  result=-1
  set +e
  while [[ result -ne 0 ]]; do
    # try to connect
    $govc_pwsh_cmd Get-ChildItem \\ 2> /dev/null
    result=$?
    sleep 1
  done
  set -e
}

function run_pwsh_command_with_govc() {
  command=$1
  echo "Running $command"
  pid=$(
    $govc_pwsh_cmd ${command}
  )
  return=$(govc guest.ps -vm.ipath="${vm_ipath}" -l="${vm_username}:${vm_password}" -p=${pid} -X -json | jq '.ProcessInfo[0].ExitCode')
  echo "${command} returned ${return}"
}

wait_for_vm_to_come_up

run_pwsh_command_with_govc 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
run_pwsh_command_with_govc 'Install-Module -Name PSWindowsUpdate -MinimumVersion 2.1.0.1 -Force'

returnWindowsUpdateCount="exit (([array](Get-WindowsUpdate)).Count)"
echo "getting update count"
get_update_count_pid=$($govc_pwsh_cmd ${returnWindowsUpdateCount})
echo "getting update count exit code via guest.ps"
updates_remaining=$(govc guest.ps -vm.ipath="${vm_ipath}" -l="${vm_username}:${vm_password}" -p=${get_update_count_pid} -X -json | jq '.ProcessInfo[0].ExitCode')
echo "Windows Updates to install: $updates_remaining"
while [[ updates_remaining -ne 0 ]]; do

  install_update_pid=$(
    $govc_pwsh_cmd Install-WindowsUpdate -AcceptAll -AutoReboot
  )
  echo "install-WU pid is $install_update_pid"


  # ignore unreachable agent if the vm just went down for reboot
  # -X blocks until the guest process exits
  set +e
  govc guest.ps -vm.ipath="${vm_ipath}" -l="${vm_username}:${vm_password}" -p=${install_update_pid} -X
  set -e
  echo "Install-WU done"

  # wait for VM to go down and poll for connectivity
  echo "Waiting for VM to come back after reboot, if necessary..."
  sleep 60
  wait_for_vm_to_come_up

  echo "VM reachable"
  updates_remaining=
  while [[ -z "$updates_remaining" ]] ; do
    echo "Trying to discover how many updates remain..."
    # ignore failures here since the vmware tools agent may be down while updates are being applied
    set +e
    get_update_count_pid=$($govc_pwsh_cmd ${returnWindowsUpdateCount})
    updates_remaining=$(govc guest.ps -vm.ipath="${vm_ipath}" -l="${vm_username}:${vm_password}" -p=${get_update_count_pid} -X -json | jq '.ProcessInfo[0].ExitCode')
    set -e
  done
  echo "Updates remaining: $updates_remaining"
done

run_pwsh_command_with_govc "Get-Hotfix > C:\\hotfix.log"

govc guest.download -l ${vm_username}:${vm_password} -vm=${vm_ipath} "C:\\hotfix.log" hotfix-log/hotfixes.log

run_pwsh_command_with_govc "Dism.exe /online /Cleanup-Image /StartComponentCleanup"
