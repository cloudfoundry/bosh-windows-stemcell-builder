$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function Unzip {
    param([string]$ZipFile, [string]$OutPath, [Switch]$Keep)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)

    if (!$Keep) {
        Write-Host "Unzip: removing zipfile ${ZipFile}"
        Remove-Item -Path $ZipFile -Force
    }
}

$attemptsLeft = 10
while (!(Test-Path "C:\provision\bosh-psmodules.zip") -and ($attemptsLeft -ne 0)) {
    Write-Host "Checking for bosh-psmodules.zip..."
    $attemptsLeft--
    Start-Sleep 3600
}

if ($attemptsLeft -eq 0) {
    Write-Error "Could not find bosh-psmodules.zip"
    Exit 1
}

$path = "C:\Program Files\WindowsPowerShell\Modules"
Remove-Item -Path (Join-Path $path "BOSH.*") -Force -Recurse

Unzip -ZipFile "C:\provision\bosh-psmodules.zip" -OutPath $path -Keep $false
Import-Module BOSH.Utils
