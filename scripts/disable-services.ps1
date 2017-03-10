$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Get-Service WinRM | Set-Service -StartupType Disabled
Get-Service W3Svc | Set-Service -StartupType Disabled

Exit 0
