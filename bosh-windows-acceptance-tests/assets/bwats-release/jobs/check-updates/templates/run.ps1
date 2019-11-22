$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

$Session = New-Object -ComObject Microsoft.Update.Session
Write-Host "Session: $Session"
$Searcher = $Session.CreateUpdateSearcher()
Write-Host "Searcher: $Searcher"
$UninstalledUpdates = $Searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0").Updates
$FilteredUpdates = @($UninstalledUpdates | `
    Where-Object {$_.Title -notmatch "KB2267602" -And $_.Title -NotMatch "KB4052623"})
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
