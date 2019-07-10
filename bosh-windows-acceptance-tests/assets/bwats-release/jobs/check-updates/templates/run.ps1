$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

# Uninstall any existing remnants of MBSA
Start-Process -FilePath MSIExec -ArgumentList /uninstall,"C:\var\vcap\packages\mbsa\MBSASetup-x64-EN.msi", /qn -Wait

# Install MBSA
Start-Process -FilePath "C:\var\vcap\packages\mbsa\MBSASetup-x64-EN.msi" -ArgumentList "/quiet" -Wait

# Run MBSA
Set-Service -Name wuauserv -StartupType Manual
Start-Service -Name wuauserv

$MbsaCli = "C:\Program Files\Microsoft Baseline Security Analyzer 2\mbsacli.exe"
$Output = & $MbsaCli /ia /n Password+IIS+OS+SQL
$Failed = $Output | Select-String "Check failed" | Select-String -NotMatch "non-critical"

If (!!$Failed) {
  $Missing = $Output | Select-String "missing" | Select-String -NotMatch "No security updates are missing"
  Write-Host "########## MBSA found missing updates. Debug purposes only, disregard error. ############ Missing: $Missing"
}


$Session = New-Object -ComObject Microsoft.Update.Session
Write-Host "Session: $Session"
$Searcher = $Session.CreateUpdateSearcher()
Write-Host "Searcher: $Searcher"
$UninstalledUpdates = $Searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0").Updates
$FilteredUpdates = @($UninstalledUpdates | Where-Object {$_.Title -notmatch "KB2267602"})
if ($FilteredUpdates.Count -ne 0) {
    Write-Log "The following updates are not currently installed:"
    foreach ($Update in $FilteredUpdates) {
        Write-Log "> $($Update.Title)"
    }
    Write-Error 'There are uninstalled updates'
    Exit 1
} else {
  Write-Host "No pending updates found by UpdateSearcher"
}

Write-Host "Finished checking updates."
