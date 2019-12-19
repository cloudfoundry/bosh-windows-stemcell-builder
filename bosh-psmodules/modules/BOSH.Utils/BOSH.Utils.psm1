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

   New-Item -Path $(split-path $LogFile -parent) -ItemType Directory -Force | Out-Null

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

    Write-Log "Protect-Dir: Grant Administrator"
    cmd.exe /c cacls.exe $path /T /E /P Administrators:F
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Remove BUILTIN\Users"
    cmd.exe /c cacls.exe $path /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Remove BUILTIN\IIS_IUSRS"
    cmd.exe /c cacls.exe $path /T /E /R "BUILTIN\IIS_IUSRS"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    if ($disableInheritance) {
        Write-Log "Protect-Dir: Disable Inheritance"
        $acl = Get-ACL -LiteralPath $path
        $acl.SetAccessRuleProtection($True, $True)
        Set-Acl -LiteralPath $path -AclObject $acl
    }
}

function Protect-Path {
   Param(
       [string]$path = $(Throw "Provide a directory to set ACL on"),
       [bool]$disableInheritance=$True
   )

   Write-Log "Protect-Path: Grant Administrator"
   cmd.exe /c cacls.exe $path /E /P Administrators:F
   if ($LASTEXITCODE -ne 0) {
       Throw "Error setting ACL for $path exited with $LASTEXITCODE"
   }

   Write-Log "Protect-Path: Remove BUILTIN\Users"
   cmd.exe /c cacls.exe $path /E /R "BUILTIN\Users"
   if ($LASTEXITCODE -ne 0) {
       Throw "Error setting ACL for $path exited with $LASTEXITCODE"
   }

   Write-Log "Protect-Path: Remove BUILTIN\IIS_IUSRS"
   cmd.exe /c cacls.exe $path /E /R "BUILTIN\IIS_IUSRS"
   if ($LASTEXITCODE -ne 0) {
       Throw "Error setting ACL for $path exited with $LASTEXITCODE"
   }

   if ($disableInheritance) {
       Write-Log "Protect-Path: Disable Inheritance"
       $acl = Get-ACL -LiteralPath $path
       $acl.SetAccessRuleProtection($True, $True)
       Set-Acl -LiteralPath $path -AclObject $acl
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

    function Add-ProxySettings {
        Param(
            [Parameter(Mandatory=$False)]
            [string]$Proxy
        ,
            [Parameter(Mandatory=$False)]
            [string]$BypassProxy
        )

        [string] $start =  [System.Text.Encoding]::ASCII.GetString([byte[]](70, 0, 0, 0, 25, 0, 0, 0, 3, 0, 0, 0, 29, 0, 0, 0 ), 0, 16);
        [string] $endproxy = [System.Text.Encoding]::ASCII.GetString([byte[]]( 233, 0, 0, 0 ), 0, 4);
        [string] $end = [System.Text.Encoding]::ASCII.GetString([byte[]]( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), 0, 36);

        [string] $text = "$($start)$($Proxy)$($endproxy)$($BypassProxy)$($end)";
        [byte[]] $data = [System.Text.Encoding]::ASCII.GetBytes($text);

        $regKeyConnections = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
        Set-ItemProperty -Path $regKeyConnections -Name "DefaultConnectionSettings" -Value $data -ErrorVariable err 2>&1 | Out-Null
        Write-Host "Added the IE registry key"
        if ($err -ne "") {
            throw "Failed to set proxy settings: $($err)"
        }
    }

    if ($ProxyServerString) {
        Add-ProxySettings $ProxyServerString $BypassList

        #Also add NetSH proxy settings for Windows-Updates
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
    $regKeyConnections = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
    $item = Get-Item $regKeyConnections
    if ($item.Property) {
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name "DefaultConnectionSettings"

        #We need to pipe the command through Out-String in order to convert its output into a proper string
        $reset_proxy = (& cmd.exe /c "netsh winhttp reset proxy") | Out-String
        Write-Log "Cleared proxy settings: $reset_proxy"
    } else {
        Write-Log "No proxy settings set. There is nothing to clear."
    }
}

function Disable-RC4() {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers' -Name 'RC4 128/128' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers' -Name 'RC4 40/128' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers' -Name 'RC4 56/128' -Force

    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128' -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128' -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128' -Value 0 -Name 'Enabled' -Type DWORD
}

function Disable-TLS1() {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\' -Name 'TLS 1.0' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0' -Name 'Server' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0' -Name 'Client' -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -Value 1 -Name 'DisabledByDefault' -Type DWORD

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -Value 1 -Name 'DisabledByDefault' -Type DWORD
}

function Disable-TLS11() {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\' -Name 'TLS 1.1' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1' -Name 'Server' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1' -Name 'Client' -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" -Value 1 -Name 'DisabledByDefault' -Type DWORD

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -Value 0 -Name 'Enabled' -Type DWORD
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" -Value 1 -Name 'DisabledByDefault' -Type DWORD
}


function Enable-TLS12() {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\' -Name 'TLS 1.2' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2' -Name 'Server' -Force
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2' -Name 'Client' -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Value 1 -Name 'Enabled' -Type DWORD

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -Value 1 -Name 'Enabled' -Type DWORD
}

function Disable-3DES() {
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\' -Name 'Triple DES 168' -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168" -Value 0 -Name 'Enabled' -Type DWORD
}

function Disable-DCOM() {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\OLE" -Value 'N' -Name 'EnableDCOM'
}

function Get-OSVersionString {
    return [System.Environment]::OSVersion.Version.ToString()
}

function Get-OSVersion {
    try
    {
        $osVersion = Get-OSVersionString
        if ($osVersion -match "6\.3\.9600\..+")
        {
            Write-Log "Found OS version: Windows 2012R2"
            "windows2012R2"
        }
        elseif ($osVersion -match "10\.0\.16299\..+")
        {
            Write-Log "Found OS version: Windows 1709"
            "windows2016"
        }
        elseif ($osVersion -match "10\.0\.17134\..+")
        {
            Write-Log "Found OS version: Windows 1803"
            "windows1803"
        }
        elseif ($osVersion -match "10\.0\.17763\..+")
        {
            Write-Log "Found OS version: Windows 2019"
            "windows2019"
        }
        else {
            throw "invalid OS detected"
        }
    }
    catch [Exception]
    {
        Write-Log $_.Exception.Message
        throw $_.Exception
    }
}

function New-VersionFile {
    param([string]$Version)

    if (!$Version) {
        throw "-Version parameter must be specified as major.minor[.whatever]"
    }

    $truncatedVersion = $Version.Split('.')[0..1] -Join '.'

    New-Item -Path "C:\\var\\vcap\\bosh\\etc" -ItemType 'directory'
    New-Item -Path "C:\\var\\vcap\\bosh\\etc\\stemcell_version" -ItemType 'file' -Value $truncatedVersion
}

function Get-WinRMConfig {
    Invoke-Expression "winrm get winrm/config" -OutVariable result -ErrorVariable err 2>&1 | Out-Null

    if ($err -ne "") {
        throw "Failed to get WinRM config: $err"
    }

    return $result
}

function Get-WUCerts {
    Write-Log "Loading certs from windows update server"
    $sstfile = SST-Path
    Invoke-Certutil -generateSSTFromWU $sstfile
    Invoke-Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root -FilePath $sstfile
    Invoke-Remove-Item -path $sstfile
}

function SST-Path {
    return [System.IO.Path]::GetTempPath() + 'roots.sst'
}

function Invoke-Import-Certificate {
    Param(
        [Parameter(Mandatory=$True)]
        [string]$CertStoreLocation
        ,
        [Parameter(Mandatory=$True)]
        [string]$FilePath
        )
    Import-Certificate -CertStoreLocation $CertStoreLocation -FilePath $FilePath
    if ($LASTEXITCODE -ne 0) {
        Throw "Error importing cert file from windows update server, exited with $LASTEXITCODE"
    }
}

function Invoke-Certutil {
    Param(
        [Parameter(Mandatory=$True)]
        [string]$generateSSTFromWU
        )
    certutil -generateSSTFromWU $generateSSTFromWU
    if ($LASTEXITCODE -ne 0) {
        Throw "Error generating cert file from windows update server, exited with $LASTEXITCODE"
    }
}

function Invoke-Remove-Item {
    Param(
        [Parameter(Mandatory=$True)]
        [string]$path
        )
    Remove-Item -path $path
}

function Enable-Hyper-V {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -norestart
}
