Set-PSDebug -Trace 1

$ErrorActionPreference = "Stop";
trap { Exit 1 }

$ROOT_DIR=Get-Location
$OUTPUT_DIR=Join-Path $ROOT_DIR output
$VERSION=Get-Content (Join-Path (Join-Path $ROOT_DIR version) version)

$env:PATH += ";c:\var\vcap\packages\git\usr\bin"

Write-Host ***Building Stembuild***

Set-Location stembuild\stembuild

$INPUT_ZIP_GLOB=Join-Path $ROOT_DIR $env:STEMCELL_AUTOMATION_ZIP

Copy-Item -Path $INPUT_ZIP_GLOB "assets\StemcellAutomation.zip" -Recurse -Force

make STEMCELL_VERSION=${VERSION} build

Write-Host ***Copying stembuild to output directory***
Copy-Item out/stembuild.exe $OUTPUT_DIR/stembuild-windows-x86_64-$VERSION.exe
