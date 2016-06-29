
# Removes unused Windows features.

Write-Host "Removing unused Windows features..."
Remove-WindowsFeature -Name 'Powershell-ISE'
Get-WindowsFeature |
? { $_.InstallState -eq 'Available' } |
Uninstall-WindowsFeature -Remove

Write-Host "Cleaning up the WinSxS folder..."
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Host "Defragging..."
Optimize-Volume -DriveLetter C



Write-Host "Recreate Pagefile after sysprep"
$System = GWMI Win32_ComputerSystem -EnableAllPrivileges
$System.AutomaticManagedPagefile = $true
$System.Put()
