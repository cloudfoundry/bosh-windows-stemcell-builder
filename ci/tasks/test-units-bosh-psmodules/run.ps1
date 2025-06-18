function New-TemporaryDirectory {
  $tmp = [System.IO.Path]::GetTempPath() # Not $env:TEMP, see https://stackoverflow.com/a/946017
  $name = (New-Guid).ToString("N")
  New-Item -ItemType Directory -Path (Join-Path $tmp $name)
}
$moduleDir = New-TemporaryDirectory
$pesterModule = Find-Module -Name Pester -MaximumVersion "5.9999" -MinimumVersion "5.0"
$pesterModule | Save-Module -Path $moduleDir
Import-Module "$moduleDir\Pester\$($pesterModule.Version)\Pester.psm1"

$status = (Get-Service -Name "wuauserv").Status
$startupType = Get-Service "wuauserv" | Select-Object -ExpandProperty StartType | Out-String
"wuauserv status = * $status *"
"wuauserv startuptype = * $startupType *"

$result = 0

$testModules = Get-ChildItem "stemcell-builder\$env:MODULES_DIR" -recurse | Where-Object {$_.name -match ".*.Tests.ps1"} | ForEach-Object {$_.DirectoryName}
foreach ($module in $testModules) {
    Write-Host "Testing: $module"
    Push-Location "$module"

    # Do not set $ErrorActionPreference and let Pester handle it nativetly; setting it to Stop globally will
    # break the tests since they are written with the assumption non zero exit codes will not fail a test
    # See: https://github.com/pester/Pester/issues/1404#issuecomment-568659518 for details
    $results=Invoke-Pester -PassThru # append "-Output Diagnostic" for verbose output
    if ($results.FailedCount -gt 0) {
      $result += $results.FailedCount
    }

    Pop-Location
}

Write-Output "Failed Test Count: $result"
exit $result
