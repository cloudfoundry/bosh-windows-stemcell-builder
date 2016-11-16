# Install the PSWindowsUpdate PowerShell module.

$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

param([string]$script:ZipFile)

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

    Remove-Item -Path $zipfile -Force
}

$ModuleDir = "${env:USERPROFILE}\Documents\WindowsPowerShell\Modules"

$exists = Test-Path -Path "${ModuleDir}\PSWindowsUpdate"
if ($exists -eq $TRUE) {
    Write-Host "PSWindowsUpdate already installed"
    Exit 0
}

Write-Host "Extracting PSWindowsUpdate zip (${script:ZipFile}) to: (${ModuleDir})"

New-Item -ItemType "directory" -Path "${ModuleDir}" -Force
Unzip $script:ZipFile $ModuleDir

Exit 0
