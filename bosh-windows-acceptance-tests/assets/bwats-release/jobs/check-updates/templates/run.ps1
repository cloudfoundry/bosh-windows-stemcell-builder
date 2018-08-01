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
  Write-Error "Found missing updates: $Missing"
  Exit 1
}

Write-Host "Finished checking updates."
