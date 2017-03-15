<#
.Synopsis
    Common Utils
.Description
    This cmdlet enables common utils for BOSH
#>

function Write-Log {
   Param (
   [Parameter(Mandatory=$True,Position=1)][string]$Message,
   [string]$LogFile="C:\provision\log.log"
   )

   $LogDir = (split-path $LogFile -parent)
   If ((Test-Path $LogDir) -ne $True) {
     New-Item -Path $LogDir -ItemType Directory -Force
   }

   $msg = "{0} {1}" -f (Get-Date -Format o), $Message
   Add-Content -Path $LogFile -Value $msg -Encoding 'UTF8'
   Write-Host $msg
}

function Open-Zip {
    param([string]$ZipFile, [string]$OutPath, [bool]$Keep=$True)

    $ZipFile = (Resolve-Path $ZipFile).Path
    $OutPath = (Resolve-Path $OutPath).Path
    Write-Log "Unzipping: ${ZipFile} to ${OutPath}"

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)

    if (!$Keep) {
        Write-Log "Unzip: removing zipfile ${ZipFile}"
        Remove-Item -Path $ZipFile -Force
    }
}
