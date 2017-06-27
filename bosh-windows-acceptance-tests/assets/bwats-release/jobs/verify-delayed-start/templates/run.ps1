$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

# The Agent's start type will no longer be 'Automatic (Delayed)',
# it will instead be 'Manual', so we check for the presence of
# the below registry key, which is an artifact of the original
# delayed setting.
#
$RegPath="HKLM:\SYSTEM\CurrentControlSet\Services\bosh-agent"

if ((Get-ItemProperty  $RegPath).DelayedAutostart -ne 1) {
    Write-Error "Expected DelayedAutostart to equal 1"
    Exit 1
}

Exit 0
