Set-PSDebug -Trace 1

$ErrorActionPreference = "Stop";
trap { Exit 1 }

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir
Set-VCenterHostAndCert

$env:PATH += ";c:\var\vcap\packages\git\usr\bin"

$ROOT_DIR=Get-Location
Write-Host "ROOT: $ROOT_DIR"

$TMP_DIR=Join-Path $ROOT_DIR tmp

Write-Host *** creating and setting temp environment variable to $TMP_DIR***
New-Item $TMP_DIR -ItemType Directory

$env:TMP=$TMP_DIR
$env:TEMP=$TMP_DIR
$env:SystemTemp=$TMP_DIR

$env:VM_NAME= cat $ROOT_DIR/integration-vm-name/name
$env:STEMBUILD_VERSION = cat $ROOT_DIR/version/version

$vcenterCertPath="$TMP_DIR\vcenter_ca.crt"
Write-Output $env:VCENTER_CA_CERT > $vcenterCertPath
$env:GOVC_TLS_CA_CERTS=$vcenterCertPath

Set-Location stemcell-builder\stembuild

Write-Host ***Runninng integration tests***
make integration
if ($lastexitcode -ne 0)
{
    Write-Host "Last exit code: ", $lastexitcode
    throw "integration specs failed"
}
