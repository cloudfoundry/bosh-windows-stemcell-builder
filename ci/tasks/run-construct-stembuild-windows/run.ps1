Set-PSDebug -Trace 2

$ErrorActionPreference = "Stop";
trap { Exit 1 }

$ROOT_DIR=Get-Location

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir
Set-VCenterHostAndCert

Copy-Item lgpo-binary/LGPO*.zip "$ROOT_DIR\LGPO.zip"

$ca_cert_file="$ROOT_DIR\ca.crt"
$env:VCENTER_CA_CERT | Set-Content "$ca_cert_file"

Copy-Item -Path stembuild-untested-windows/stembuild* "$ROOT_DIR\stembuild.exe"
ICACLS "$ROOT_DIR\stembuild.exe" /grant:r "users:(RX)" /C

.\stembuild.exe -debug construct `
    -vcenter-url $env:VCENTER_BASE_URL `
        -vcenter-username $env:VCENTER_USERNAME `
        -vcenter-password $env:VCENTER_PASSWORD `
    -vcenter-ca-certs $ca_cert_file `
    -vm-inventory-path $env:VCENTER_VM_FOLDER/$env:STEMBUILD_BASE_VM_NAME `
    -vm-ip $env:STEMBUILD_BASE_VM_IP `
        -vm-username $env:STEMBUILD_BASE_VM_USERNAME `
        -vm-password $env:STEMBUILD_BASE_VM_PASSWORD `
    -setup-arg FailOnInstallWUCerts

exit $LASTEXITCODE
