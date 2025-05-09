Set-PSDebug -Trace 1

$ErrorActionPreference = "Stop";
trap { Exit 1 }

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir
Set-VCenterHostAndCert

$env:PATH += ";c:\var\vcap\packages\git\usr\bin"

$ROOT_DIR=Get-Location
Write-Host "ROOT: $ROOT_DIR"

$env:VM_NAME= cat $ROOT_DIR/integration-vm-name/name
$env:BOSH_PSMODULES_REPO="$ROOT_DIR/bosh-psmodules-repo"

$TMP_DIR=Join-Path $ROOT_DIR tmp

Write-Host *** creating and setting temp environment variable to $TMP_DIR***
New-Item $TMP_DIR -ItemType Directory

$env:TMP=$TMP_DIR
$env:TEMP=$TMP_DIR
$env:SystemTemp=$TMP_DIR

$env:TARGET_VM_IP = cat $ROOT_DIR/nimbus-ips/name
$env:STEMBUILD_VERSION = cat $ROOT_DIR/version/version

Set-Location stembuild\stembuild

Write-Host ***Runninng integration tests***
make integration
if ($lastexitcode -ne 0)
{
    Write-Host "Last exit code: ", $lastexitcode
    throw "integration specs failed"
}
