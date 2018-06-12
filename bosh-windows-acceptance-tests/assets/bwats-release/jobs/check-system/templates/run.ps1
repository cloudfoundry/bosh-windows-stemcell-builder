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

# Check WinRM
If ( (Get-Service WinRM).Status -ne "Stopped") {
  $msg = "WinRM is not Stopped. It is {0}" -f $(Get-Service WinRM).Status
  Write-Error $msg
  Exit 1
}

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

# Check metadata server
$MetadataServerAllowRules = Get-NetFirewallRule -Enabled True -Direction Outbound | Get-NetFirewallAddressFilter | Where-Object -FilterScript { $_.RemoteAddress -Eq '169.254.169.254' }
If ($MetadataServerAllowRules -Ne $null) {
  $RuleNames = $MetadataServerAllowRules | foreach { $_.InstanceID }
  If ($RuleNames.Count -ne 2 ) {
    Write-Error "Expected 2 firewall rules"
    $RuleNames
    Exit 1
  }
  If ($RuleNames -notcontains "Allow-BOSH-Agent-Metadata-Server") {
    Write-Error "Did not find rule Allow-BOSH-Agent-Metadata-Server"
    Exit 1
  }
  If ($RuleNames -notcontains "Allow-GCEAgent-Metadata-Server") {
    Write-Error "Did not find rule Allow-GCEAgent-Metadata-Server"
    Exit 1
  }
}


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
function Assert-IsInstalled {
  param (
    [string] $feature= (Throw "feature param required")
  )
  If (!(Get-WindowsFeature $feature).Installed) {
    Write-Error "Failed to find $feature"
    Exit 1
  } else {
    Write-Host "Found $feature feature"
  }
}
function Assert-IsNotInstalled {
  Param (
    [string] $feature = (Throw "feature param required")
  )
  If ((Get-WindowsFeature $feature).Installed) {
    Write-Error "$feature should not be installed"
    Exit 1
  } else {
    Write-Host "$feature is not installed"
  }
}

# Ensure correct CF Windows features are installed
if ($windowsVersion -Match "2012") {
  Assert-IsInstalled "Web-Webserver"
  Assert-IsInstalled "Web-WebSockets"
  Assert-IsInstalled "AS-Web-Support"
  Assert-IsInstalled "AS-NET-Framework"
  Assert-IsInstalled "Web-WHC"
  Assert-IsInstalled "Web-ASP"
} elseif ($windowsVersion -Match "2016") {
  Assert-IsInstalled "Containers"
  Assert-IsNotInstalled "Windows-Defender-Features"
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

# Verify the Agent's start type is 'Manual'.
#
$agent = Get-Service | Where { $_.Name -eq 'bosh-agent' }
if ($agent -eq $null) {
    Write-Error "Missing service: bosh-agent"
    Exit 1
}
if ($agent.StartType -ne "Manual") {
    Write-Error "verify-agent-start-type: bosh-agent start type is not 'Manual' got: '$($agent.StartType.ToString())'"
    Exit 1
}

# The Agent's start type will no longer be 'Automatic (Delayed)',
# it will instead be 'Manual', so we check for the presence of
# the below registry key, which is an artifact of the original
# delayed setting.
#
$RegPath="HKLM:\SYSTEM\CurrentControlSet\Services\bosh-agent"

if ((Get-ItemProperty  $RegPath).DelayedAutostart -ne 1) {
    Write-Error "verify-agent-start-type: Expected DelayedAutostart to equal 1"
    Exit 1
}

$ServicesPipeTimeoutPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
if ((Get-ItemProperty  $ServicesPipeTimeoutPath).ServicesPipeTimeout -ne 60000) {
    Write-Error "Error: expected ServicesPipeTimeout to equal 60s"
    Exit 1
}

# Verify-autoupdates have been stopped
if ((Get-Service wuauserv).Status -ne "Stopped") {
    Write-Error "Error: expected wuauserv service to be Stopped"
    Exit 1
}

# Verify agent start type is not Disabled
$StartType = (Get-Service wuauserv).StartType
if ($StartType -ne "Disabled") {
    Write-Host "Warning: wuauserv service StartType is not disabled: ${StartType}"
}

# Verify randomize password has run
secedit /configure /db secedit.sdb /cfg c:\var\vcap\jobs\check-system\inf\security.inf

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$ComputerName=hostname
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)

if ($DS.ValidateCredentials('Administrator', 'Password123!')) {
    Write-Error "Administrator password was not randomized"
    Exit 1
}

$dataPartition = Get-Partition | where AccessPaths -Contains "C:\var\vcap\data\"
if ($dataPartition -ne $null) {
    Write-Error "Data partition should not be created"
    Exit 1
}

echo "Verifying NTP synch works correctly"
w32tm /query /configuration

Set-Date -Date (Get-Date).AddHours(8)
$OutOfSyncTime = Get-Date

$TimeSetCorrectly = $false

for ($i=0; $i -lt 10; $i++) {
    Sleep 1

    w32tm /resync /rediscover
    w32tm /resync

    if ((Get-Date) -ge $OutOfSyncTime) {
        Write-Error "Time not reset correctly via NTP on attempt $($i+1) of 10"
    } else {
        $TimeSetCorrectly = $true
        break
    }
}

if (-not $TimeSetCorrectly) {
    Write-Error "Time not reset correctly via NTP after 10 attempts"
    Exit 1
}

# Verify LGPO
if ($windowsVersion -Match "2012") {
  echo "Verifying that expected policies have been applied"

  lgpo /b $PSScriptRoot
  $LgpoDir = "$PSScriptRoot\" + (Get-ChildItem $PSScriptRoot -Directory | ?{ $_.Name -match "{*}" } | select -First 1).Name

  $OutputDir="$PSScriptRoot\lgpo_test"
  mkdir $OutputDir

  lgpo /parse /m "$LgpoDir\DomainSysvol\GPO\Machine\registry.pol" > "$OutputDir\machine_registry.unedited.txt"
  Get-Content "$OutputDir\machine_registry.unedited.txt" | select -Skip 3 > "$OutputDir\machine_registry.txt"

  lgpo /parse /u "$LgpoDir\DomainSysvol\GPO\User\registry.pol" > "$OutputDir\user_registry.unedited.txt"
  Get-Content "$OutputDir\user_registry.unedited.txt" | select -Skip 3 > "$OutputDir\user_registry.txt"

  copy "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv" "$OutputDir"
  $Csv     = Import-Csv "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv"
  $Include = $Csv[0].psobject.properties | select -ExpandProperty Name -Skip 1
  $Csv | select $Include | export-csv "$OutputDir\audit.csv" -NoTypeInformation

  copy "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" "$OutputDir"

  function Assert-NoDiff {
    Param (
      [string] $fileA = (Throw "first filename param required"),
      [string] $fileB = (Throw "second filename param required")
    )
    fc.exe /t "$fileA" "$fileB"

    if ($LastExitCode -ne 0) {
      Write-Error "Expected no diff between $fileA and $fileB"
      Exit 1
    }
  }

  # Diff the files aginst the fixtures
  $TestDir = "$PSScriptRoot\..\test"

  Assert-NoDiff "$OutputDir\machine_registry.txt" "$TestDir\machine_registry.txt"
  Assert-NoDiff "$OutputDir\user_registry.txt" "$TestDir\user_registry.txt"
  Assert-NoDiff "$OutputDir\GptTmpl.inf" "$TestDir\GptTmpl.inf"
  Assert-NoDiff "$OutputDir\audit.csv" "$TestDir\audit.csv"
}

Exit 0
