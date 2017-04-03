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

function Get-Log {
   Param (
   [string]$LogFile="C:\\provision\\log.log"
   )

   if (Test-Path $LogFile) {
      Get-Content -Path $LogFile
   } else {
      Throw "Missing log file: $LogFile"
   }
}

function Open-Zip {
    param(
    [string]$ZipFile= $(Throw "Provide a ZipFile to extract"),
    [string]$OutPath= $(Throw "Provide an OutPath for extract"),
    [bool]$Keep=$True)

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

function New-Provisioner {
   param(
   [string]$Dir="C:\\provision"
   )

   if (Test-Path $Dir) {
      Remove-Item -Path $Dir -Recurse -Force
   }
   New-Item -ItemType Directory -Path $Dir
}

function Clear-Provisioner {
   param(
   [string]$Dir="C:\\provision"
   )

   if (Test-Path $Dir) {
      Remove-Item -Path $Dir -Recurse -Force
      if (Test-Path $Dir) {
         Throw "Unable to clean provisioner: $Dir"
      }
   } else {
      Throw "Missing provisioner dir: $Dir"
   }
}
