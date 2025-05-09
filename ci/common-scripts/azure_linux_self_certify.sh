#!/bin/bash

function heading() {
  echo;echo
  echo "$1"
}

function run() {
  echo "$1"
  eval "$1"
  echo "------------------------------------------------------------"
}

heading "LinuxDistro"
run "cat /etc/*-release"

heading "LinuxKernel version"
run "cat /proc/version"

heading "Python version"
run "python -V"

heading "Agent version"
run "waagent -version"

heading "Swap Partition"
run "sudo -S -i cat /etc/fstab"
run "swapon -s"
run "sudo -S -i cat /etc/waagent.conf"

heading "Kernal Parameters"
run "cat /proc/cmdline"

heading "Client Alive Interval"
run "sudo -S -i sshd -T"

heading "Batch History"
run 'sudo -S -i find / -name ".bash_history" -o -name ".history"'
run "sudo stat -c "%s" /root/.bash_history"

heading "Open SSL Version"
run "openssl version"

heading "Os Architecture"
run "uname -m"

heading "Root Partition"
run "mount | grep -c sda"
