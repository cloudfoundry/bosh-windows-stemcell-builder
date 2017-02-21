# winrm quickconfig -q
cmd.exe /c 'winrm quickconfig -q'
"winrm quickconfig -q (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -transport:http
cmd.exe /c 'winrm quickconfig -transport:http'
"winrm quickconfig -transport:http (Exit Code: ${LASTEXITCODE})"

# Win RM MaxTimoutms
cmd.exe /c 'winrm set winrm/config @{MaxTimeoutms="1800000"}'
"Win RM MaxTimoutms (Exit Code: ${LASTEXITCODE})"

# Win RM MaxMemoryPerShellMB
cmd.exe /c 'winrm set winrm/config/winrs @{MaxMemoryPerShellMB="800"}'
"Win RM MaxMemoryPerShellMB (Exit Code: ${LASTEXITCODE})"

# Win RM AllowUnencrypted
cmd.exe /c 'winrm set winrm/config/service @{AllowUnencrypted="true"}'
"Win RM AllowUnencrypted (Exit Code: ${LASTEXITCODE})"

# Win RM auth Basic
cmd.exe /c 'winrm set winrm/config/service/auth @{Basic="true"}'
"Win RM auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM client auth Basic
cmd.exe /c 'winrm set winrm/config/client/auth @{Basic="true"}'
"Win RM client auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM listener Address/Port
cmd.exe /c 'winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"}'
"Win RM listener Address/Port (Exit Code: ${LASTEXITCODE})"

# Win RM adv firewall enable
cmd.exe /c 'netsh advfirewall firewall set rule group="remote administration" new enable=yes'
"Win RM adv firewall enable (Exit Code: ${LASTEXITCODE})"

# Win RM port open
cmd.exe /c 'netsh firewall add portopening TCP 5985 "Port 5985"'
"Win RM port open (Exit Code: ${LASTEXITCODE})"

# Stop Win RM Service
cmd.exe /c 'net stop winrm'
"Stop Win RM Service (Exit Code: ${LASTEXITCODE})"

# Show file extensions in Explorer
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f'
"Show file extensions in Explorer"

# Enable QuickEdit mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\Console /v QuickEdit /t REG_DWORD /d 1 /f'
"Enable QuickEdit mode"

# Show Run command in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f'
"Show Run command in Start Menu"

# Show Administrative Tools in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f'
"Show Administrative Tools in Start Menu"

# Zero Hibernation File
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateFileSizePercent /t REG_DWORD /d 0 /f'
"Zero Hibernation File"

# Disable Hibernation Mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateEnabled /t REG_DWORD /d 0 /f'
"Disable Hibernation Mode"

# Disable password expiration for Administrator user
cmd.exe /c 'wmic useraccount where "name=''Administrator''" set PasswordExpires=FALSE'
"Disable password expiration for Administrator user (Exit Code: ${LASTEXITCODE})"

# Win RM Autostart
cmd.exe /c 'sc config winrm start=auto'
"Win RM Autostart (Exit Code: ${LASTEXITCODE})"

# Start Win RM Service
cmd.exe /c 'net start winrm'
"Start Win RM Service (Exit Code: ${LASTEXITCODE})"
