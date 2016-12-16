# Disable winrm
Get-Service WinRM | Stop-Service -PassThru | Set-Service -StartupType Disabled
Set-Service -name WinRM -StartupType Disabled

get-wmiobject win32_service | where Name -eq WinRM

winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Basic="false"}'

netsh advfirewall firewall set rule name="WinRM 5985" new enable=no
netsh advfirewall firewall set rule name="WinRM 5986" new enable=no

net stop winrm
sc config winrm start=disabled
