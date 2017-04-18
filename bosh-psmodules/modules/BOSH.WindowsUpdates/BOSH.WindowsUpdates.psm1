<#
.Synopsis
    Install Windows Updates
.Description
    This cmdlet installs all available Windows Updates in batches
#>

# Do not place these inside a function - they will not behave as expected
$script:ScriptName = $MyInvocation.MyCommand.ToString()
$script:ScriptPath = $MyInvocation.MyCommand.Path

function Register-WindowsUpdatesTask {
    $Prin = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
    -Argument "-Command `"Install-WindowsUpdates`" "
    $trigger =  New-ScheduledTaskTrigger -AtLogon -RandomDelay 00:00:30
    Register-ScheduledTask -Principal $Prin -Action $action -Trigger $trigger -TaskName "InstallWindowsUpdates" -Description "InstallWindowsUpdates"
}

function Unregister-WindowsUpdatesTask {
        Unregister-ScheduledTask -TaskName "InstallWindowsUpdates" -Confirm:$false
}

function Wait-WindowsUpdates {
    Param([string]$Password,[string]$User)

    Enable-Autologon -Password $Password -User $User
    shutdown /r /c "packer restart" /t 5
    Disable-WinRM
}

function Install-WindowsUpdates {

    $script:UpdateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $script:UpdateSession.ClientApplicationID = 'BOSH.WindowsUpdates'
    $script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
    $script:SearchResult = New-Object -ComObject 'Microsoft.Update.UpdateColl'

    $script:Cycles = 0
    $script:CycleUpdateCount = 0
    $script:MaxUpdatesPerCycle=500
    $script:RestartRequired=0
    $script:MoreUpdates=0
    $script:MaxCycles=5

    Get-UpdateBatch
    if ($script:MoreUpdates -eq 1) {
        Install-UpdateBatch
    } else {
        Invoke-RebootOrComplete
    }
}

function Invoke-RebootOrComplete() {
    $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $RegistryEntry = "InstallWindowsUpdates"
    switch ($script:RestartRequired) {
        0 {
            $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
            if ($prop) {
                Write-Log "Restart Registry Entry Exists - Removing It"
                Remove-ItemProperty -Path $RegistryKey -Name $RegistryEntry -ErrorAction SilentlyContinue
            }

            Write-Log "No Restart Required"
            Get-UpdateBatch

            if (($script:MoreUpdates -eq 1) -and ($script:Cycles -le $script:MaxCycles)) {
                Install-UpdateBatch
            } elseif ($script:Cycles -gt $script:MaxCycles) {
                Write-Log "Exceeded Cycle Count - Stopping"
                Enable-WinRM
                Disable-Autologon
            } else {
                Write-Log "Done Installing Windows Updates"
                Enable-WinRM
                Disable-Autologon
            }
        }
        1 {
            $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
            if (-not $prop) {
                Write-Log "Restart Registry Entry Does Not Exist - Creating It"
                Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy Bypass -Command Install-WindowsUpdates"
            } else {
                Write-Log "Restart Registry Entry Exists Already"
            }

            Write-Log "Restart Required - Restarting..."
            Restart-Computer
        }
        default {
            Write-Log "Unsure If A Restart Is Required"
            break
        }
    }
}

function Install-UpdateBatch() {
    $script:Cycles++
    Write-Log "Evaluating Available Updates with limit of $($script:MaxUpdatesPerCycle):"
    $UpdatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    $script:i = 0;
    if ($Host.Version.Major -eq 5) {
      $CurrentUpdates = $SearchResult.Updates
    } else {
      $CurrentUpdates = $SearchResult.Updates | Select-Object
    }
    while($script:i -lt $SearchResult.Updates.Count -and $script:CycleUpdateCount -lt $script:MaxUpdatesPerCycle) {
        $Update = $CurrentUpdates[$script:i]
        if (($null -ne $Update) -and (!$Update.IsDownloaded)) {
            [bool]$addThisUpdate = $false
            if ($Update.InstallationBehavior.CanRequestUserInput) {
                Write-Log "> Skipping: $($Update.Title) because it requires user input"
            } else {
                if (!($Update.EulaAccepted)) {
                    Write-Log "> Note: $($Update.Title) has a license agreement that must be accepted. Accepting the license."
                    $Update.AcceptEula()
                    [bool]$addThisUpdate = $true
                    $script:CycleUpdateCount++
                } else {
                    [bool]$addThisUpdate = $true
                    $script:CycleUpdateCount++
                }
            }

            if ([bool]$addThisUpdate) {
                Write-Log "Adding: $($Update.Title)"
                $UpdatesToDownload.Add($Update) |Out-Null
            }
        }
        $script:i++
    }

    if ($UpdatesToDownload.Count -eq 0) {
        Write-Log "No Updates To Download..."
    } else {
        Write-Log 'Downloading Updates...'
        $ok = 0;
        while (! $ok) {
            try {
                $Downloader = $UpdateSession.CreateUpdateDownloader()
                $Downloader.Updates = $UpdatesToDownload
                $Downloader.Download()
                $ok = 1;
            } catch {
                Write-Log $_.Exception | Format-List -force
                Write-Log "Error downloading updates. Retrying in 30s."
                $script:attempts = $script:attempts + 1
                Start-Sleep -s 30
            }
        }
    }

    $UpdatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    [bool]$rebootMayBeRequired = $false
    Write-Log 'The following updates are downloaded and ready to be installed:'
    foreach ($Update in $SearchResult.Updates) {
        if (($Update.IsDownloaded)) {
            Write-Log "> $($Update.Title)"
            $UpdatesToInstall.Add($Update) |Out-Null

            if ($Update.InstallationBehavior.RebootBehavior -gt 0){
                [bool]$rebootMayBeRequired = $true
            }
        }
    }

    if ($UpdatesToInstall.Count -eq 0) {
        Write-Log 'No updates available to install...'
        $script:MoreUpdates=0
        $script:RestartRequired=0
        Enable-WinRM
        break
    }

    if ($rebootMayBeRequired) {
        Write-Log 'These updates may require a reboot'
        $script:RestartRequired=1
    }

    Write-Log 'Installing updates...'

    $Installer = $script:UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()

    Write-Log "Installation Result: $($InstallationResult.ResultCode)"
    Write-Log "Reboot Required: $($InstallationResult.RebootRequired)"
    Write-Log 'Listing of updates installed and individual installation results:'
    if ($InstallationResult.RebootRequired) {
        $script:RestartRequired=1
    } else {
        $script:RestartRequired=0
    }

    for($i=0; $i -lt $UpdatesToInstall.Count; $i++) {
        New-Object -TypeName PSObject -Property @{
            Title = $UpdatesToInstall.Item($i).Title
            Result = $InstallationResult.GetUpdateResult($i).ResultCode
        }
        Write-Log "Item: $UpdatesToInstall.Item($i).Title"
        Write-Log "Result: $InstallationResult.GetUpdateResult($i).ResultCode"
    }

    Invoke-RebootOrComplete
}

function Get-UpdateBatch() {
    Write-Log "Checking For Windows Updates"
    $Username = $env:USERDOMAIN + "\" + $env:USERNAME

    New-EventLog -Source $script:ScriptName -LogName 'Windows Powershell' -ErrorAction SilentlyContinue

    $Message = "Script: " + $script:ScriptPath + "`nScript User: " + $Username + "`nStarted: " + (Get-Date).toString()

    Write-EventLog -LogName 'Windows Powershell' -Source $script:ScriptName -EventID "104" -EntryType "Information" -Message $Message
    Write-Log $Message

    $script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
    $script:successful = $FALSE
    $script:attempts = 0
    $script:maxAttempts = 12
    while(-not $script:successful -and $script:attempts -lt $script:maxAttempts) {
        try {
            $script:SearchResult = $script:UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            $script:successful = $TRUE
        } catch {
            Write-Log $_.Exception | Format-List -force
            Write-Log "Search call to UpdateSearcher was unsuccessful. Retrying in 10s."
            $script:attempts = $script:attempts + 1
            Start-Sleep -s 10
        }
    }

    if ($SearchResult.Updates.Count -ne 0) {
        $Message = "There are " + $SearchResult.Updates.Count + " more updates."
        Write-Log $Message
        try {
            for($i=0; $i -lt $script:SearchResult.Updates.Count; $i++) {
              Write-Log $script:SearchResult.Updates.Item($i).Title
              Write-Log $script:SearchResult.Updates.Item($i).Description
              Write-Log $script:SearchResult.Updates.Item($i).RebootRequired
              Write-Log $script:SearchResult.Updates.Item($i).EulaAccepted
          }
            $script:MoreUpdates=1
        } catch {
            Write-Log $_.Exception | Format-List -force
            Write-Log "Showing SearchResult was unsuccessful. Rebooting."
            $script:RestartRequired=1
            $script:MoreUpdates=0
            Invoke-RebootOrComplete
            Write-Log "Show never happen to see this text!"
            Restart-Computer
        }
    } else {
        Write-Log 'There are no applicable updates'
        $script:RestartRequired=0
        $script:MoreUpdates=0
    }
}

function Search-InstalledUpdates() {
    $Session = New-Object -ComObject Microsoft.Update.Session
    $Searcher = $Session.CreateUpdateSearcher()
    $Searcher.Search("IsInstalled=1").Updates | Sort-Object LastDeploymentChangeTime | ForEach-Object { "KB$($_.KBArticleIDs) | $($_.Title)" }
}

function Test-InstalledUpdates() {
    $Session = New-Object -ComObject Microsoft.Update.Session
    $Searcher = $Session.CreateUpdateSearcher()
    $UninstalledUpdates = $Searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0").Updates
    if ($UninstalledUpdates.Count -ne 0) {
        Write-Log "The following updates are not currently installed:"
        foreach ($Update in $UninstalledUpdates) {
            Write-Log "> $($Update.Title)"
        }
        Throw 'There are uninstalled updates'
    }
}

function List-InstalledUpdates() {
    $successful = $FALSE
    $attempts = 0
    $maxAttempts = 5
    $result = @()
    while(-not $successful -and $attempts -lt $maxAttempts) {
        try {
            $result = Search-InstalledUpdates
            $successful = $TRUE
        } catch {
            Write-Log $_.Exception | Format-List -force
            Write-Log "Search call to UpdateSearcher was unsuccessful. Retrying in 5s."
            $attempts = $attempts + 1
            Start-Sleep -s 5
        }
    }

    if (-not $successful) {
        Throw "Could not find any installed updates"
    }

    $result
}

<#
.Synopsis
    Disable Automatic Updates
.Description
    This cmdlet disables automatic Windows Updates
#>
function Disable-AutomaticUpdates() {
    Stop-Service -Name wuauserv
    Set-Service -Name wuauserv -StartupType Disabled

    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 1 -Name 'AUOptions'
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 0 -Name 'EnableFeaturedSoftware'
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 0 -Name 'IncludeRecommendedUpdates'
}
