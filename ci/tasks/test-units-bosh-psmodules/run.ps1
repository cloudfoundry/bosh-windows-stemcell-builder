$ErrorActionPreference = "Stop"
# Do not set error action preference let Pester handle it instead
$result = 0

Import-Module ./Pester/pester.psm1;
$status = (Get-Service -Name "wuauserv").Status
$startupType = Get-Service "wuauserv" | Select-Object -ExpandProperty StartType | Out-String
"wuauserv status = * $status *"
"wuauserv startuptype = * $startupType *"

foreach ($module in (Get-ChildItem "./bosh-psmodules-repo/modules").Name) {
  Push-Location "./bosh-psmodules-repo/modules/$module"
    $results=Invoke-Pester -PassThru
    if ($results.FailedCount -gt 0) {
      $result += $results.FailedCount
    }
  Pop-Location
}
echo "Failed Tests: $result"
exit $result
