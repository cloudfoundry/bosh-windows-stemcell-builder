param(
    [string]$Organization = "",
    [string]$Owner = "",
    [switch]$SkipRandomPassword
)

$postRebootExceptionExitCode = 2

Push-Location $PSScriptRoot

Import-Module ./AutomationHelpers.psm1

try {
    PostReboot -Organization $Organization -Owner $Owner -SkipRandomPassword $SkipRandomPassword
} catch [Exception] {
    Write-Log "Failed to prepare the VM. See 'c:\provision\log.log' for more info."
    Exit $postRebootExceptionExitCode
}

Pop-Location
