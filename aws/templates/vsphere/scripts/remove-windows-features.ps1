# Removes unused Windows features.

Remove-WindowsFeature -Name 'Powershell-ISE'
Get-WindowsFeature |
? { $_.InstallState -eq 'Available' } |
Uninstall-WindowsFeature -Remove
