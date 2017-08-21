$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

# Verify the Agent's start type is 'Manual'.
#
$agent = Get-Service | Where { $_.Name -eq 'bosh-agent' }
if ($agent -eq $null) {
    Write-Error "Missing service: bosh-agent"
    Exit 1
}
if ($agent.StartType -ne "Manual") {
    Write-Error "verify-agent-start-type: bosh-agent start type is not 'Manual' got: '$($agent.StartType.ToString())'"
    Exit 1
}

# The Agent's start type will no longer be 'Automatic (Delayed)',
# it will instead be 'Manual', so we check for the presence of
# the below registry key, which is an artifact of the original
# delayed setting.
#
$RegPath="HKLM:\SYSTEM\CurrentControlSet\Services\bosh-agent"

if ((Get-ItemProperty  $RegPath).DelayedAutostart -ne 1) {
    Write-Error "verify-agent-start-type: Expected DelayedAutostart to equal 1"
    Exit 1
}
