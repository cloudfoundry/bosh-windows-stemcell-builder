$Logfile = "C:\Windows\Temp\initial-setup.log"
$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RegistryEntry = "InstallWindowsUpdates"

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
        Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File $($script:ScriptPath)"
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
Check-WindowsUpdates

# Set Execution Policy 64 Bit
cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"
LogWrite "Set Execution Policy 64 Bit"

# Set Execution Policy 32 Bit
C:\Windows\SysWOW64\cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"
LogWrite "Set Execution Policy 32 Bit"

# winrm quickconfig -q
cmd.exe /c winrm quickconfig -q
LogWrite "winrm quickconfig -q"

# winrm quickconfig -transport:http
cmd.exe /c winrm quickconfig -transport:http
LogWrite "winrm quickconfig -transport:http"

# Win RM MaxTimoutms
cmd.exe /c winrm set winrm/config @{MaxTimeoutms="1800000"}
LogWrite "Win RM MaxTimoutms"

# Win RM MaxMemoryPerShellMB
cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB="800"}
LogWrite "Win RM MaxMemoryPerShellMB"

# Win RM AllowUnencrypted
cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted="true"}
LogWrite "Win RM AllowUnencrypted"

# Win RM auth Basic
cmd.exe /c winrm set winrm/config/service/auth @{Basic="true"}
LogWrite "Win RM auth Basic"

# Win RM client auth Basic
cmd.exe /c winrm set winrm/config/client/auth @{Basic="true"}
LogWrite "Win RM client auth Basic"

# Win RM listener Address/Port
cmd.exe /c winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"}
LogWrite "Win RM listener Address/Port"

# Win RM adv firewall enable
cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
LogWrite "Win RM adv firewall enable"

# Win RM port open
cmd.exe /c netsh firewall add portopening TCP 5985 "Port 5985"
LogWrite "Win RM port open"

# Stop Win RM Service
cmd.exe /c net stop winrm
LogWrite "Stop Win RM Service"

# Show file extensions in Explorer
# %SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f
# LogWrite "Show file extensions in Explorer"

# Enable QuickEdit mode
# %SystemRoot%\System32\reg.exe ADD HKCU\Console /v QuickEdit /t REG_DWORD /d 1 /f
# LogWrite "Enable QuickEdit mode"

# Show Run command in Start Menu
# %SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f
# LogWrite "Show Run command in Start Menu"

# Show Administrative Tools in Start Menu
# %SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f
# LogWrite "Show Administrative Tools in Start Menu"

# Zero Hibernation File
# %SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateFileSizePercent /t REG_DWORD /d 0 /f
# LogWrite "Zero Hibernation File"

# Disable Hibernation Mode
# %SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateEnabled /t REG_DWORD /d 0 /f
# LogWrite "Disable Hibernation Mode"

# Disable password expiration for Administrator user
cmd.exe /c wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE
LogWrite "Disable password expiration for Administrator user"

# Win RM Autostart
cmd.exe /c sc config winrm start=auto
LogWrite "Win RM Autostart"

# Start Win RM Service
cmd.exe /c net start winrm
LogWrite "Start Win RM Service"

