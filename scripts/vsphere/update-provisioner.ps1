param([String]$AdminPassword="Password123!", [String]$DebugLog="")

# DO NOT CHECK FOR ERRORS IN THIS FILE!

# UPDATES
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDirectory = Split-Path $ScriptPath -Parent
Import-Module (Join-Path "$ScriptDirectory" "PowershellUtils")

# Unzip PSWindowsUpdate.zip
$modulePath = (Join-Path "$ScriptDirectory" "PSWindowsUpdate")
if (-Not (Test-Path $modulePath)) {
    # Unzip PSWindowsUpdate into the script directory.
    Unzip "$modulePath.zip" (Split-Path $modulePath -Parent)
}
Import-Module $modulePath

################################################################################
# Globals
################################################################################

$UpdateLog="C:\update-logs.txt" # WARN: Change me!

# Update Search Criteria
#
# Categories are chosen from: https://support.microsoft.com/en-us/kb/824684
$UpdateCategories = "Security Updates", "Critical Updates", "Windows Server 2012 R2", "Updates", "Feature Packs", "Update Rollups"
$IgnoredUpdateCategories =  "Silverlight"

################################################################################
# Functions
################################################################################

$Script:ExecutedEnableMicrosoftUpdates = $false
function EnableMicrosoftUpdates {
    if ($Script:ExecutedEnableMicrosoftUpdates) {
        LogWrite $UpdateLog "EnableMicrosoftUpdates: already ran - skipping"
        return
    }
    $Script:ExecutedEnableMicrosoftUpdates = $true

    LogWrite $UpdateLog "EnableMicrosoftUpdates: enabling Microsoft Update ServiceManager"

    # If the service is not running this errors.
    net stop wuauserv

    $scriptPath = "${env:TEMP}\enable-microsoft-updates.vbs"
    cmd.exe /C ('echo Set ServiceManager = CreateObject("Microsoft.Update.ServiceManager") > {0}' -f $scriptPath)
    cmd.exe /C ('echo Set NewUpdateService = ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"") >> {0}' -f $scriptPath)
    cscript.exe $scriptPath

    # If the service is running this errors.
    net start wuauserv
}

function Install-Updates() {
    LogWrite $UpdateLog "Got here 0"

    # Loop until we successfully connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        LogWrite $UpdateLog "Got here 1"
        try {
            LogWrite $UpdateLog "Got here 2"
            $updateResult = Get-WUInstall -MicrosoftUpdate -AutoReboot -AcceptAll -IgnoreUserInput -Debuger -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories
            LogWrite $UpdateLog "Got here 3"
            return $updateResult
        } catch {
            LogWrite $UpdateLog "Got here 4"
            if ($_ -match "HRESULT: 0x8024402C") {
                LogWrite $UpdateLog "Install-Updates: error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                LogWrite $UpdateLog "Install-Updates: error ${$_}"
                # Throw $_
                # return -1
            }
        }
    }
    LogWrite $UpdateLog "Install-Updates: failed after ${maxAttempts}"
    # Throw "Install-Updates: failed after ${maxAttempts}"
    # return 0
    # return -1
}

function Update-Count() {
    EnableMicrosoftUpdates

    # Loop until we successfully connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        try {
            $count = (Get-WUList -MicrosoftUpdate -IgnoreUserInput -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories | measure).Count
            return $count
        } catch {
            if ($_ -match "HRESULT: 0x8024402C") {
                LogWrite $UpdateLog "Error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                Throw $_
                return -1
            }
        }
    }
    Throw "Update-Count: failed after ${maxAttempts}"
    return 0
}

$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RegistryEntry = "InstallWindowsUpdates"

function Add-AutoRun() {
    param([parameter(Mandatory=$true)] [String] $AdminPassword)

    # Enable auto-logon - required for auto-run
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /d 1 /f
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /d Administrator /f
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /d "${AdminPassword}" /f

    $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
    if (-not $prop) {
        LogWrite $UpdateLog "Restart Registry Entry Does Not Exist - Creating It"
        Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File {0} -DebugLog {1} *>> {1}" -f `
            $ScriptPath, $DebugLog
    } else {
        LogWrite $UpdateLog "Restart Registry Entry Exists Already"
    }
}

function Remove-AutoRun() {
    # TODO (CEV): delete DefaultUserName and DefaultPassword subkeys.
    # Remove auto-logon
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /d 0 /f

    $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
    if ($prop) {
        LogWrite $UpdateLog "Restart Registry Entry Exists - Removing It"
        Remove-ItemProperty -Path $RegistryKey -Name $RegistryEntry -ErrorAction SilentlyContinue
    }
}

function CompileDotNetAssemblies {
    LogWrite $UpdateLog "Compiling dotnet assemblies..."
    if (Test-Path "$env:windir\microsoft.net\framework\v4.0.30319\ngen.exe") {
        & $env:windir\microsoft.net\framework\v4.0.30319\ngen.exe update /force /queue
        & $env:windir\microsoft.net\framework\v4.0.30319\ngen.exe executequeueditems
    }
    if (Test-Path "$env:windir\microsoft.net\framework64\v4.0.30319\ngen.exe") {
        & $env:windir\microsoft.net\framework64\v4.0.30319\ngen.exe update /force /queue
        & $env:windir\microsoft.net\framework64\v4.0.30319\ngen.exe executequeueditems
    }
}

function CompactDisk {
    $Volume = Get-WmiObject win32_volume | where {$_.name -eq "${env:HOMEDRIVE}\"}

    function DefragDisk {
        # Defrag the volume
        $Volume.Defrag($true)
    }

    LogWrite $UpdateLog "CompactDisk: defrag pass 1/3"
    DefragDisk

    $Success = $TRUE
    $FilePath = "${env:HOMEDRIVE}\zero.tmp"
    LogWrite $UpdateLog "CompactDisk: zeroing volume: $Volume"

    $ArraySize = 64kb
    $SpaceToLeave = $Volume.Capacity * 0.05
    $FileSize = $Volume.FreeSpace - $SpacetoLeave
    LogWrite $UpdateLog "CompactDisk: writing ($FileSize bytes) to $FilePath"

    $ZeroArray = New-Object byte[]($ArraySize)
    $Stream = [io.File]::OpenWrite($FilePath)
    $CurFileSize = 0
    while ($CurFileSize -lt $FileSize) {
        $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
        $CurFileSize +=$ZeroArray.Length
    }
    if ($Stream) {
        $Stream.Close()
    }

    LogWrite $UpdateLog "CompactDisk: defrag pass 2/3"
    DefragDisk

    Remove-Item -Path $FilePath -Force

    LogWrite $UpdateLog "CompactDisk: defrag pass 3/3"
    DefragDisk # Just for good measure
}

function CleanupWindowsFeatures {
    # WARN (CEV): Keeping Powershell-ISE for now
    #
    # LogWrite $UpdateLog "Removing Powershell-ISE"
    # Get-WindowsFeature 'Powershell-ISE' | Uninstall-WindowsFeature -Remove

    # Removes unused Windows features.
    LogWrite $UpdateLog "Removing unused Windows features"
    Get-WindowsFeature | ? { $_.InstallState -eq 'Available' } | Uninstall-WindowsFeature -Remove

    # Cleanup WinSxS folder: https://technet.microsoft.com/en-us/library/dn251565.aspx
    LogWrite $UpdateLog "Cleaning up WinSxS directory with: 'Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase'"
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    LogWrite $UpdateLog "Cleaning up WinSxS directory with: 'Dism.exe /online /Cleanup-Image /SPSuperseded'"
    Dism.exe /online /Cleanup-Image /SPSuperseded 
}

# TODO (CEV): Fail if a feature cannot be installed
function InstallWindowsFeatures() {
    function WindowsFeatureInstall([string]$feature)
    {
        If (!(Get-WindowsFeature $feature).Installed) {
            LogWrite $UpdateLog "InstallWindowsFeatures: installing $feature"
            Install-WindowsFeature $feature
            If (!(Get-WindowsFeature $feature).Installed) {
                LogWrite $UpdateLog "InstallWindowsFeatures: failed to install $feature"
                Write-Error "InstallWindowsFeatures: failed to install $feature"
            }
        } else {
            LogWrite $UpdateLog "InstallWindowsFeatures: already installed $feature"
        }
    }

    WindowsFeatureInstall("Web-Webserver")
    WindowsFeatureInstall("Web-WebSockets")
    WindowsFeatureInstall("AS-Web-Support")
    WindowsFeatureInstall("AS-NET-Framework")
    WindowsFeatureInstall("Web-WHC")
    WindowsFeatureInstall("Web-ASP")
}

# Security and things
function InitialSetup() {
    InstallWindowsFeatures

    # Set Execution Policy 64 Bit
    LogWrite $UpdateLog "InitialSetup: Set Execution Policy 64 Bit: 'RemoteSigned'"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

    # Set Execution Policy 32 Bit
    LogWrite $UpdateLog "InitialSetup: Set Execution Policy 32 Bit: 'RemoteSigned'"
    & "${env:windir}\SysWOW64\cmd.exe" /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"

    LogWrite $UpdateLog "InitialSetup: disabling service: WinRM"
    Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Disabled

    LogWrite $UpdateLog "InitialSetup: disabling service: W3Svc"
    Get-Service | Where-Object {$_.Name -eq "W3Svc" } | Set-Service -StartupType Disabled
}

# Run last!
function PostSetup {
    LogWrite $UpdateLog "Enable-WinRM: setting StartupType to 'Auto'"
    Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Auto
}

################################################################################
# Script Block
################################################################################

# Run first!
InitialSetup

# TODO: use Update-Count
$Script:PendingUpdates=$true

# TODO: actually check if updates were installed
$Script:InstalledNewUpdates=$true

if ($PendingUpdates) {
    LogWrite $UpdateLog "Preparing to install pending updates"

    Add-AutoRun -AdminPassword $AdminPassword

    while (Update-Count -ge 0) {
        # TODO (CEV): Find persistent (through restarts) way to signal updates were installed.
        # $Script:InstalledNewUpdates=$true

        # TODO (CEV): handle errors - and remove autorun
        LogWrite $UpdateLog "Installing updates"
        Install-Updates
        LogWrite $UpdateLog "Finished updates"
    }

    Remove-AutoRun

    if ($Script:InstalledNewUpdates) {
        LogWrite $UpdateLog "New updates installed: running post-update provisioners..."
        CompileDotNetAssemblies

        LogWrite $UpdateLog "Cleaning up windows features..."
        CleanupWindowsFeatures

        LogWrite $UpdateLog "Defragging and zeroing disk: C:\"
        CompactDisk
    }
}

# WARN (CEV): Attempting to trigger this script via another
Remove-AutoRun

PostSetup

Restart-Computer -Force
