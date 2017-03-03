$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function DisableService {
    param([string] $name)

    # Don't error if it does not exist
    Get-Service | Where-Object {$_.Name -eq $name } | Set-Service -StartupType Disabled
}

DisableService "WinRM"
DisableService "W3Svc"

Exit 0
