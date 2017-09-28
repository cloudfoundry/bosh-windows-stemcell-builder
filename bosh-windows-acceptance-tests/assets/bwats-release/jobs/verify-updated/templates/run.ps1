Start-Sleep -Seconds 180

Set-Service -Name wuauserv -StartupType Manual
Start-Service -Name wuauserv

Start-Sleep -Seconds 180

Test-InstalledUpdates

exit 0
