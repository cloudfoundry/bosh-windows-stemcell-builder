# Removes unused Windows features.

Remove-WindowsFeature -Name 'Powershell-ISE'
Get-WindowsFeature |
? { $_.InstallState -eq 'Available' } |
Uninstall-WindowsFeature -Remove

# Cleanup WinSxS folder: https://technet.microsoft.com/en-us/library/dn251565.aspx
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
Dism.exe /online /Cleanup-Image /SPSuperseded
