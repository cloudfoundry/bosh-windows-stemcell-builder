$ErrorActionPreference = "Stop";
trap { Exit 1 }

Import-Module ./bosh-windows-stemcell-builder-ci/ci/common-scripts/setup-windows-container.psm1
Set-TmpDir
Set-VCenterHostAndCert

$env:VCENTER_CA_CERT | Set-Content ca.crt

pushd stembuild-untested-windows
    Move-Item stembuild* stembuild.exe
popd

Move-Item stembuild-untested-windows/stembuild.exe .

ICACLS stembuild.exe /grant:r "users:(RX)" /C

$version="$(cat .\build-number\number)"
$stemcellBuildNumber="$(Get-Date -Format "yyyyMMddHHmm")"
$patch,$build=$version.split('.')[2,3]
$patch_version="$patch.$build$stemcellBuildNumber"

.\stembuild.exe package -vcenter-url $env:VCENTER_BASE_URL -vcenter-username $env:VCENTER_USERNAME -vcenter-password $env:VCENTER_PASSWORD -vm-inventory-path $env:VCENTER_VM_FOLDER/$env:STEMBUILD_BASE_VM_NAME -patch-version $patch_version -vcenter-ca-certs "ca.crt"

$stembuild_exit_code=$LASTEXITCODE
If (!($stembuild_exit_code -eq 0)) {
    exit $stembuild_exit_code
} Else {
    Move-Item *.tgz stembuild-built-stemcell
}
