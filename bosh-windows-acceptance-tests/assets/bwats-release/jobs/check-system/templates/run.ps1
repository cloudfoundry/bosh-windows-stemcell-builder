# Do not set ErrorActionPreference to stop as Get-Acl will error
# if we do not have permission to read file permissions.

# Check for dependencies

$BOSH_BIN="C:\\var\\vcap\\bosh\\bin"
Write-Host "Checking $BOSH_BIN dependencies"

$files = New-Object System.Collections.ArrayList
[void] $files.AddRange((
    "bosh-blobstore-s3.exe",
    "bosh-blobstore-dav.exe",
    "tar.exe",
    "job-service-wrapper.exe"
))

Get-ChildItem $BOSH_BIN | ForEach-Object {
  Write-Host "Checking for $_.Name"
  $files.remove($_.Name)
}

If ($files.Count -gt 0) {
  Write-Error "Unable to find the following binaries: $($files -join ',')"
  Exit 1
}

# Check ACLs

$expectedacls = New-Object System.Collections.ArrayList
[void] $expectedacls.AddRange((
    "${env:COMPUTERNAME}\Administrator,Allow",
    "NT AUTHORITY\SYSTEM,Allow",
    "BUILTIN\Administrators,Allow",
    "CREATOR OWNER,Allow",
    "APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES,Allow"
))

# for 2016, for some reason every file in C:\Program Files\OpenSSH
# ends up with "APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES,Allow".
# adding this to unblock 2016 pipeline
$windowsVersion = [environment]::OSVersion.Version.Major
if ($windowsVersion -ge "10") {
  "Adding 2016 ACLs"
  $expectedacls.Add("APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES,Allow")
}

function Check-Acls {
    param([string]$path)

    $errCount = 0

    Get-ChildItem -Path $path -Recurse | foreach {
      $name = $_.FullName
      If (-Not ($_.Attributes -match "ReparsePoint")) {
        Get-Acl $name | Select -ExpandProperty Access | ForEach-Object {
          $ident = ('{0},{1}' -f $_.IdentityReference, $_.AccessControlType).ToString()
          If (-Not $expectedacls.Contains($ident)) {
            If (-Not ($ident -match "NT [\w]+\\[\w]+,Allow")) {
              $errCount += 1
                Write-Host "Error ($name): $ident"
            }
          }
        }
      }
    }

    return $errCount
}

$errCount = 0
$errCount += Check-Acls "C:\var"
$errCount += Check-Acls "C:\bosh"
$errCount += Check-Acls "C:\Windows\Panther\Unattend"
$errCount += Check-Acls "C:\Program Files\OpenSSH"
if ($errCount -ne 0) {
    Write-Error "FAILED: $errCount"
    Exit 1
}

# Check Services

# Check sshd startup type
If ( (Get-Service sshd).StartType -ne "Disabled") {
  $msg = "sshd is not disabled. It is {0}" -f $(Get-Service sshd).StartType
  Write-Error $msg
  Exit 1
}

# Check ssh-agent startup type
If ( (Get-Service ssh-agent).StartType -ne "Disabled") {
  $msg = "ssh-agent is not disabled. It is {0}" -f $(Get-Service ssh-agent).StartType
  Write-Error $msg
  Exit 1
}

# Check firewall rules
function get-firewall {
  param([string] $profile)
  $firewall = (Get-NetFirewallProfile -Name $profile)
  $result = "{0},{1},{2}" -f $profile,$firewall.DefaultInboundAction,$firewall.DefaultOutboundAction
  return $result
}

function check-firewall {
  param([string] $profile)
  $firewall = (get-firewall $profile)
  Write-Host $firewall
  if ($firewall -ne "$profile,Block,Allow") {
    Write-Host $firewall
    Write-Error "Unable to set $profile Profile"
    Exit 1
  }
}

check-firewall "public"
check-firewall "private"
check-firewall "domain"

$windowsVersion = (Get-WmiObject -class Win32_OperatingSystem).Caption

if ($windowsVersion -Match "2012") {
  # Ensure HWC apps can get started
  Start-Process -FilePath "C:\var\vcap\jobs\check-system\bin\HWCServer.exe" -ArgumentList "9000"
  $status = (Invoke-WebRequest -Uri "http://localhost:9000" -UseBasicParsing).StatusCode
  If ($status -ne 200) {
    Write-Error "Failed to start HWC app"
    Exit 1
  } else {
    Write-Host "HWC apps can start"
  }

  $status = try { Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing } catch {}
  If ($status -ne $nil) {
    Write-Error "IIS Web Server is not turned off"
    Exit 1
  } else {
    Write-Host "IIS Web Server is turned off"
  }
}

# Check installed features

$windowsFeatures = @()
if ($windowsVersion -Match "2012") {
  $windowsFeatures = @(
    "Web-Webserver",
    "Web-WebSockets",
    "AS-Web-Support",
    "AS-NET-Framework",
    "Web-WHC",
    "Web-ASP"
  )
} elseif ($windowsVersion -Match "2016") {
  $windowsFeatures = @("Containers")
}

# Ensure CF Windows features are installed
$features = New-Object System.Collections.ArrayList
[void] $features.AddRange($windowsFeatures)
foreach ($feature in $features) {
  If (!(Get-WindowsFeature $feature).Installed) {
    Write-Error "Failed to find $feature"
    Exit 1
  } else {
    Write-Host "Found $feature feature"
  }
}

# Ensure docker is installed on Windows2016
if ($windowsVersion -Match "2016") {
  if ((Get-Command "docker.exe" -ErrorAction SilentlyContinue) -eq $null) {
    Write-Error "Docker is not installed"
    Exit 1
  } else {
    write-host "Docker is installed"
    docker.exe history microsoft/windowsservercore
    if ($? -eq $False) {
      Write-Error "microsoft/windowsservercore image is not downloaded"
      Exit 1
    } else {
      Write-Host "microsoft/windowsservercore image is downloaded"
    }
  }
}

#Ensure provisioner user is deleted
$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$user = "Provisioner"
$existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $user }
if ( $existing -eq $null){
  Write-Host "$user user is deleted"
} else {
  Write-Error "$user user still exists. Please run 'Remove-Account -User $user'"
  Exit 1
}

# We have a chore (https://www.pivotaltracker.com/story/show/149592041)
# to ensure the Provisioner user's home directory is deleted when the user
# is removed.
#
# if ((Resolve-Path "C:\Users\$user*").Length -ne 0) {
#   Write-Error "User $user home dir still exists"
#   Exit 1
# }

$DisabledNetBIOS = $false
$nbtstat = nbtstat.exe -n
"results for nbtstat: $nbtstat"

$nbtstat | foreach {
    $DisabledNetBIOS = $DisabledNetBIOS -or $_ -like '*No names in cache*'
}

Exit 0
