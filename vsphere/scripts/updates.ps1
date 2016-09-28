function LogWrite {
   Param ([string]$logstring)
   $file = "C:\Windows\Temp\updates.log"
   $now = Get-Date -format s
   Add-Content $file -value "$now $logstring"
   Write-Host $logstring
}

$IgnoredUpdateCategories = "Feature Packs", "Update Rollups", "Silverlight"

$UpdateCategories = "Security Updates", "Critical Updates", "Windows Server 2012 R2", "Updates"

function Install-Updates() {
    # Loop until we successful connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        try {
            $updateResult = Get-WUInstall -MicrosoftUpdate -AutoReboot -AcceptAll -IgnoreUserInput -Debuger -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories
            return $updateResult
        } catch {
            if ($_ -match "HRESULT: 0x8024402C") {
                Write-Warning "Error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                Throw $_
                Exit 1
            }
        }
    }
    return $FALSE
}

function Update-Count() {
    # Loop until we successful connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        try {
            $count = (Get-WUList -MicrosoftUpdate -IgnoreUserInput -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories | measure).Count
            return $count
        } catch {
            if ($_ -match "HRESULT: 0x8024402C") {
                Write-Warning "Error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                Throw $_
                Exit 1
            }
        }
    }
    return $FALSE
}

LogWrite "Checking for Windows updates"
try {
    Import-Module PSWindowsUpdate

    # Loop until there are no more updates
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        LogWrite "Installing updates attempt #$i"
        Install-Updates
        LogWrite "Finished updates attempt #$i"

        $count = Update-Count
        if ($count -eq 0) {
            LogWrite "No more updates to install"
            Exit 0
        } else {
            LogWrite "There are $count updates to install, will retry in $sleepSeconds..."
            Start-Sleep -Seconds $sleepSeconds
        }
    }
} catch {
    LogWrite $_.Exception | Format-List -Force
    Exit 1
}
