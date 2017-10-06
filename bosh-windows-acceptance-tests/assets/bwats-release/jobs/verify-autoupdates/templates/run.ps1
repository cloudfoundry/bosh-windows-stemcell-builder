$ReturnCode = 0

if ((Get-Service wuauserv).Status -ne "Stopped") {
    Write-Error "Error: expected wuauserv service to be Stopped"
    $ReturnCode = 1
}

$StartType = (Get-Service wuauserv).StartType
if ($StartType -ne "Disabled") {
    Write-Host "Warning: wuauserv service StartType is not disabled: ${StartType}"
}

Exit $ReturnCode
