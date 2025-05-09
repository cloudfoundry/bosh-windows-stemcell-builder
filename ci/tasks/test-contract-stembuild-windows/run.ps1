Set-PSDebug -Trace 1

$ErrorActionPreference = "Stop";
trap { Exit 1 }

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir

$ROOT_DIR=Get-Location

Write-Host ***Test Stembuild Code***

Set-Location stembuild\stembuild

make contract
if ($lastexitcode -ne 0)
{
  throw "contract tests failed"
}
