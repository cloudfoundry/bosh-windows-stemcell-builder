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

   $msg = "{0} {1}" -f (Get-Date -Format o), $Message
   Add-Content -Path $LogFile -Value $msg -Encoding 'UTF8'
   Write-Host $msg
}

function Open-Zip {
    param([string]$ZipFile, [string]$OutPath, [Switch]$Keep)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)

    if (!$Keep) {
        Write-Host "Unzip: removing zipfile ${ZipFile}"
        Remove-Item -Path $ZipFile -Force
    }
}
