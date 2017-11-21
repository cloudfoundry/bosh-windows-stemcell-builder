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
    Remove-Item "$OutPath\*" -Force -Recurse
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
   }
}

function Protect-Dir {
    Param(
        [string]$path = $(Throw "Provide a directory to set ACL on"),
        [bool]$disableInheritance=$True
    )

    if (-Not (Test-Path $path)) {
        Throw "Error setting ACL for ${path}: does not exist"
    }

    Write-Log "Protect-Dir: Remove BUILTIN\Users"
    cacls.exe $path /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Remove BUILTIN\IIS_IUSRS"
    cacls.exe $path /T /E /R "BUILTIN\IIS_IUSRS"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Grant Administrator"
    cacls.exe $path /T /E /P Administrators:F
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    if ($disableInheritance) {
        Write-Log "Protect-Dir: Disable Inheritance"
        $acl = Get-ACL -Path $path
        $acl.SetAccessRuleProtection($True, $True)
        Set-Acl -Path $path -AclObject $acl
    }
}

function Set-ProxySettings {
    Param([string]$HTTPProxy,[string]$HTTPSProxy,[string]$BypassList)

    $ProxyServerString = ""
    if ($HTTPProxy) {
        $ProxyServerString = "http=$HTTPProxy"
    }
    if ($HTTPSProxy) {
        $ProxyServerString = "$ProxyServerString;https=$HTTPSProxy"
    }

    if ($ProxyServerString) {
        $set_proxy = ""
        if ($BypassList) {
            $set_proxy = & cmd.exe /c "netsh winhttp set proxy proxy-server=`"$ProxyServerString`" bypass-list=`"$BypassList`""
        } else {
            $set_proxy = & cmd.exe /c "netsh winhttp set proxy proxy-server=`"$ProxyServerString`""
        }
        Write-Log "$set_proxy"

        if ($LASTEXITCODE -ne 0) {
            exit(1)
        }
    }
}

function Clear-ProxySettings {
    $reset_proxy = & cmd.exe /c "netsh winhttp reset proxy"
    Write-Log "$reset_proxy"

    if ($LASTEXITCODE -ne 0) {
        exit(1)
    }
}