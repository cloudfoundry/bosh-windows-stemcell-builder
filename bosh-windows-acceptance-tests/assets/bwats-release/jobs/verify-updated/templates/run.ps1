Set-Service -Name wuauserv -StartupType Manual
Start-Service -Name wuauserv

Test-InstalledUpdates

exit 0
