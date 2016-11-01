param($SkipUpdates=0)

## Turn off Updates TEMP
$SkipUpdates=1

$Logfile = "C:\Windows\Temp\initial-setup.log"
$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RegistryEntry = "InstallWindowsUpdates"
$NetworkSettingsPath = "A:\network-interface-settings.xml"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Logfile -value "$now $logstring"
   Write-Host $logstring
}

function Remove-AutoRun() {
    $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
    if ($prop) {
        LogWrite "Restart Registry Entry Exists - Removing It"
        Remove-ItemProperty -Path $RegistryKey -Name $RegistryEntry -ErrorAction SilentlyContinue
    }
}

function Check-WindowsUpdates() {
    LogWrite "Checking for Windows updates"

    $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
    if (-not $prop) {
        LogWrite "Restart Registry Entry Does Not Exist - Creating It"
        Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File $($script:ScriptPath) -SkipUpdates $SkipUpdates"
    } else {
        LogWrite "Restart Registry Entry Exists Already"
    }

    # Make things faster (http://support.microsoft.com/kb/2570538)!
    cmd.exe /c A:\compile-dotnet-assemblies.bat

    # Required for updates.ps1
    cmd.exe /c A:\microsoft-updates.bat

    Powershell -File "A:\updates.ps1"
    $ExitCode = $LASTEXITCODE

    switch ($ExitCode) {
        0 {
            LogWrite "Updates complete"
            Remove-AutoRun
        }
        1 {
            LogWrite "Restart Required - Restarting..."
            Restart-Computer
            exit 0
        }
        2 {
            # WARN: This should never happen
            LogWrite "Error: Exceeded max cycle count..."
            Restart-Computer
            exit 0
        }
        default {
            LogWrite "Error: unexpected exit code ${ExitCode}"
            Remove-AutoRun
            break
        }
    }
}

$script:ScriptName = $MyInvocation.MyCommand.ToString()
$script:ScriptPath = $MyInvocation.MyCommand.Path

# Check for network settings xml
if (Test-Path $NetworkSettingsPath) {
    LogWrite "Found network interface settings file, applying network interface settings..."
    Powershell -File "A:\setup-network-interface.ps1" -ConfigPath $NetworkSettingsPath
    if ($LASTEXITCODE -ne 0) {
        LogWrite "Error: setup-network-interface.ps1 exited with code ${LASTEXITCODE}"
    }
    LogWrite "Applied network interface settings."
} else {
    LogWrite "Did not find network interface settings file, skipping network setup."
}

# Install PSWindowsUpdate Module
Powershell -File "A:\install-ps-windows-update-module.ps1" "A:\PSWindowsUpdate.zip"

if ($SkipUpdates -ne 0) {
    LogWrite "Skipping updates..."
} else {
    LogWrite "Starting updates..."
    Check-WindowsUpdates
}

# Set Execution Policy 64 Bit
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
LogWrite "Set Execution Policy 64 Bit (Exit Code: ${LASTEXITCODE})"

# Set Execution Policy 32 Bit
C:\Windows\SysWOW64\cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"
LogWrite "Set Execution Policy 32 Bit (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -q
cmd.exe /c 'winrm quickconfig -q'
LogWrite "winrm quickconfig -q (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -transport:http
cmd.exe /c 'winrm quickconfig -transport:http'
LogWrite "winrm quickconfig -transport:http (Exit Code: ${LASTEXITCODE})"

# Win RM MaxTimoutms
cmd.exe /c 'winrm set winrm/config @{MaxTimeoutms="1800000"}'
LogWrite "Win RM MaxTimoutms (Exit Code: ${LASTEXITCODE})"

# Win RM MaxMemoryPerShellMB
cmd.exe /c 'winrm set winrm/config/winrs @{MaxMemoryPerShellMB="800"}'
LogWrite "Win RM MaxMemoryPerShellMB (Exit Code: ${LASTEXITCODE})"

# Win RM AllowUnencrypted
cmd.exe /c 'winrm set winrm/config/service @{AllowUnencrypted="true"}'
LogWrite "Win RM AllowUnencrypted (Exit Code: ${LASTEXITCODE})"

# Win RM auth Basic
cmd.exe /c 'winrm set winrm/config/service/auth @{Basic="true"}'
LogWrite "Win RM auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM client auth Basic
cmd.exe /c 'winrm set winrm/config/client/auth @{Basic="true"}'
LogWrite "Win RM client auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM listener Address/Port
cmd.exe /c 'winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"}'
LogWrite "Win RM listener Address/Port (Exit Code: ${LASTEXITCODE})"

# Win RM adv firewall enable
cmd.exe /c 'netsh advfirewall firewall set rule group="remote administration" new enable=yes'
LogWrite "Win RM adv firewall enable (Exit Code: ${LASTEXITCODE})"

# Win RM port open
cmd.exe /c 'netsh firewall add portopening TCP 5985 "Port 5985"'
LogWrite "Win RM port open (Exit Code: ${LASTEXITCODE})"

# Stop Win RM Service
cmd.exe /c 'net stop winrm'
LogWrite "Stop Win RM Service (Exit Code: ${LASTEXITCODE})"

# Show file extensions in Explorer
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f'
LogWrite "Show file extensions in Explorer"

# Enable QuickEdit mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\Console /v QuickEdit /t REG_DWORD /d 1 /f'
LogWrite "Enable QuickEdit mode"

# Show Run command in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f'
LogWrite "Show Run command in Start Menu"

# Show Administrative Tools in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f'
LogWrite "Show Administrative Tools in Start Menu"

# Zero Hibernation File
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateFileSizePercent /t REG_DWORD /d 0 /f'
LogWrite "Zero Hibernation File"

# Disable Hibernation Mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateEnabled /t REG_DWORD /d 0 /f'
LogWrite "Disable Hibernation Mode"

# Disable password expiration for Administrator user
cmd.exe /c 'wmic useraccount where "name=''Administrator''" set PasswordExpires=FALSE'
LogWrite "Disable password expiration for Administrator user (Exit Code: ${LASTEXITCODE})"

# Win RM Autostart
cmd.exe /c 'sc config winrm start=auto'
LogWrite "Win RM Autostart (Exit Code: ${LASTEXITCODE})"

# Start Win RM Service
cmd.exe /c 'net start winrm'
LogWrite "Start Win RM Service (Exit Code: ${LASTEXITCODE})"
