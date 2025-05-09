$ErrorActionPreference = "Stop"
# DO NOT USE THE trap { exit 1 } pattern as it swallows errors

# Validate Environment and Locate Resource Files

# Test these early so that we don't waste time making the stemcell
# ignoring: VM_EXTENSIONS
#
$DestDir = $env:DESTINATION_DIR

$RequiredEnvVars=@(
    'WORKING_DIR',
    'STEMCELL_OS'
)
foreach ($key in $RequiredEnvVars) {
    if ((Get-Item env:$key).Value -eq $null) {
        Write-Error "Missing required env variable: $key"
    }
}

# TODO: Get pigz and go from pipeline (tar.exe is required by Concourse so not worth it).
$RequiredExes=@(
    'go',
    'pigz',
    'tar'
)
foreach ($exe in $RequiredExes) {
    Get-Command -CommandType Application -Name $exe > $null
}

$VersionFile=(Resolve-Path "${PWD}\azure-build-number\version*").Path
if (($VersionFile | Measure-Object).Count -ne 1) {
    if (($VersionFile | Measure-Object).Count -eq 0) {
        Write-Error "No files in 'azure-build-number' directory: ${VersionFile}"
    } else {
        Write-Error "Too many files in 'azure-build-number' directory: ${VersionFile}"
    }
    Exit 1
}

$VhdFile=(Resolve-Path "${PWD}\azure-base-vhd-uri\*vhd-uri.txt").Path
if (($VhdFile | Measure-Object).Count -ne 1) {
    if (($VhdFile | Measure-Object).Count -eq 0) {
        Write-Error "No files in 'azure-base-vhd-uri' directory: ${VhdFile}"
    } else {
        Write-Error "Too many files in 'azure-base-vhd-uri' directory: ${VhdFile}"
    }
    Exit 1
}

$TempDir=Join-Path $env:WORKING_DIR "Temp"
if (-Not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir
}

# Build azstemcell

$LocalBin="${PWD}\bin"
New-Item -ItemType directory -Path $LocalBin
$newpath = $LocalBin
$newpath += ":"
$newpath += $env:PATH

$env:PATH = $newpath

if (-Not (Test-Path "$PWD\bosh-windows-stemcell-builder-ci\ci\azstemcell")) {
    Write-Error "Missing azstemcell repository"
}

$MainPath=(Get-ChildItem -Recurse -Path "$PWD\bosh-windows-stemcell-builder-ci\ci\azstemcell" | where { $_.Name -eq 'main.go' })
if ($MainPath -eq $null) {
    Write-Error "Failed to find 'main.go' in $PWD\bosh-windows-stemcell-builder-ci\ci\azstemcell"
}
go build -o "/usr/bin/azstemcell" $MainPath.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Error "go: failed to build azstemcell ${LASTEXITCODE}"
}

# Create Stemcell
azstemcell `
    -vhdfile $VhdFile `
    -versionfile $VersionFile `
    -os $env:STEMCELL_OS `
    -dest $DestDir `
    -temp $TempDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "azcell: non-zero exit code ${LASTEXITCODE}"
}

Exit 0
