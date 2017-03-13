<#
.Synopsis
    Enables WinRM
.Description
    This cmdlet enables the WinRM endpoint using http and basic auth by default
#>
function Enable-WinRM {
    # Enable WinRM with defaults
	Write-Log "Enable WinRM"
    winrm quickconfig -q

    # Override defaults to allow unlimited shells/processes/memory
    winrm set winrm/config '@{MaxTimeoutms="7200000"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
    winrm set winrm/config/winrs '@{MaxProcessesPerShell="0"}'
    winrm set winrm/config/winrs '@{MaxShellsPerUser="0"}'

    # Enable insecure basic auth over http
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'

    # Ensure the Windows firewall allows WinRM traffic through
    Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"

    # Auto start the WinRM service
    Get-Service | Where-Object { $_.Name -eq "WinRM" } | Set-Service -StartupType Auto
}

function Disable-WinRM {
    Write-Log "Disable WinRM"
    Get-Service | Where-Object { $_.Name -eq "WinRM" } | Set-Service -StartupType Disabled
    Get-Service | Where-Object { $_.Name -eq "WinRM" } | Stop-Service
}
