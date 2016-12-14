# Disable winrm
Get-Service WinRM | Stop-Service -PassThru | Set-Service -StartupType disabled
