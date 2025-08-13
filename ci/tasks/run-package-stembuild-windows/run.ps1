Set-PSDebug -Trace 2

$ErrorActionPreference = "Stop";
trap { Exit 1 }

$ROOT_DIR=Get-Location

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir
Set-VCenterHostAndCert

$version="$(cat .\build-number\number)"
$stemcellBuildNumber="$(Get-Date -Format "yyyyMMddHHmm")"
$patch,$build=$version.split('.')[2,3]
$patch_version="$patch.$build$stemcellBuildNumber"

$ca_cert_file="$ROOT_DIR\ca.crt"
$env:VCENTER_CA_CERT | Set-Content "$ca_cert_file"

Copy-Item -Path stembuild-untested-windows/stembuild* "$ROOT_DIR\stembuild.exe"
ICACLS "$ROOT_DIR\stembuild.exe" /grant:r "users:(RX)" /C

.\stembuild.exe package `
    -vcenter-url $env:VCENTER_BASE_URL `
        -vcenter-username $env:VCENTER_USERNAME `
        -vcenter-password $env:VCENTER_PASSWORD `
    -vcenter-ca-certs $ca_cert_file `
    -vm-inventory-path $env:VCENTER_VM_FOLDER/$env:STEMBUILD_BASE_VM_NAME `
    -patch-version $patch_version

$stembuild_exit_code=$LASTEXITCODE
If (!($stembuild_exit_code -eq 0)) {
    exit $stembuild_exit_code
} Else {
    Move-Item *.tgz stembuild-built-stemcell
}
