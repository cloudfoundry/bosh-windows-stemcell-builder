# winrm quickconfig -q
cmd.exe /c 'winrm quickconfig -q'
"winrm quickconfig -q (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -transport:http
cmd.exe /c 'winrm quickconfig -transport:http'
"winrm quickconfig -transport:http (Exit Code: ${LASTEXITCODE})"

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

# Win RM Autostart
cmd.exe /c 'sc config winrm start=auto'
"Win RM Autostart (Exit Code: ${LASTEXITCODE})"

# Start Win RM Service
cmd.exe /c 'net start winrm'
"Start Win RM Service (Exit Code: ${LASTEXITCODE})"
