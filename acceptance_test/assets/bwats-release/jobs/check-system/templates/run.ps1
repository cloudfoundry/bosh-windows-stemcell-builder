$ErrorActionPreference = "Stop";

function Get-Config {
  $configPath = Join-Path $PSScriptRoot "config.json"
  Write-Host "Loading '$configPath'"
  $config = Get-Content $configPath -raw | ConvertFrom-Json
  Write-Host "Loaded '$configPath'"
  return $config
}

function Verify-LGPO
{
  Write-Host "Running this function Verify-LGPO"
  Write-Host "Verifying that expected policies have been applied"

  lgpo /b $PSScriptRoot
  $LgpoDir = "$PSScriptRoot\" + (Get-ChildItem $PSScriptRoot -Directory | Where-Object { $_.Name -match "{*}" } | Select-Object -First 1).Name

  $OutputDir = "$PSScriptRoot\lgpo_test"
  New-Item -ItemType Directory -Path $OutputDir -Force

  lgpo /parse /m "$LgpoDir\DomainSysvol\GPO\Machine\registry.pol" > "$OutputDir\machine_registry.unedited.txt"
  Get-Content "$OutputDir\machine_registry.unedited.txt" | Select-Object -Skip 3 > "$OutputDir\machine_registry.txt"

  lgpo /parse /u "$LgpoDir\DomainSysvol\GPO\User\registry.pol" > "$OutputDir\user_registry.unedited.txt"
  Get-Content "$OutputDir\user_registry.unedited.txt" | Select-Object -Skip 3 > "$OutputDir\user_registry.txt"

  Copy-Item "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv" "$OutputDir"
  $Csv = Import-Csv "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv"
  $Include = $Csv[0].psobject.properties | Select-Object -ExpandProperty Name -Skip 1
  $Csv | Select-Object $Include | export-csv "$OutputDir\audit.csv" -NoTypeInformation

  Copy-Item "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" "$OutputDir"

  function Compare-LGPOPolicies
  {
    Param (
        [Parameter(Mandatory)]
        [string] $ActualPoliciesFile,
        [Parameter(Mandatory)]
        [string] $ExpectedPoliciesFile,
        [Parameter(Mandatory)]
        [string] $PolicyDelimiter
    )
    Write-Host "actual policies $ActualPoliciesFile"
    Write-Host "expected policies $ExpectedPoliciesFile"

    $delims = [char[]]"`r`n`t "
    $ActualPolicies = (Get-Content $ActualPoliciesFile -Raw).Replace("`r`n", "`n")
    $ActualPoliciesArray = ([regex]::split($ActualPolicies, $PolicyDelimiter) | ForEach-Object { $_.Trim($delims) })

    $ExpectedPolicies = (Get-Content $ExpectedPoliciesFile -Raw).Replace("`r`n", "`n")
    $ExpectedPoliciesArray = ([regex]::split($ExpectedPolicies, $PolicyDelimiter) | ForEach-Object { $_.Trim($delims) })

    $count = 0
    foreach ($policy in $ExpectedPoliciesArray) {
      if ($policy -notin $ActualPoliciesArray) {
        Write-Error "Actual policies do not include policy: $policy"
        $count += 1
      }
    }
    if (-not $count -eq 0) {
      Write-Error "There are missing policies"
      return 1
    }
  }

  $OsVersion = Get-OSVersion
  switch ($OsVersion)
  {
    "windows2019" {
      $TestDir = "$PSScriptRoot\..\test-2019"
    }
  }

  Compare-LGPOPolicies "$OutputDir\machine_registry.txt" "$TestDir\machine_registry.txt" "\n\n"
  Compare-LGPOPolicies "$OutputDir\user_registry.txt" "$TestDir\user_registry.txt" "\n\n"
  Compare-LGPOPolicies "$OutputDir\GptTmpl.inf" "$TestDir\GptTmpl.inf" "\n"
  Compare-LGPOPolicies "$OutputDir\audit.csv" "$TestDir\audit.csv" "\n"
}

function Verify-Dependencies {
  $BOSH_BIN="C:\\var\\vcap\\bosh\\bin"
  Write-Host "Checking $BOSH_BIN dependencies"

  $files = New-Object System.Collections.ArrayList
  [void] $files.AddRange((
      "bosh-blobstore-s3.exe",
      "bosh-blobstore-dav.exe",
      "job-service-wrapper.exe"
  ))

  Get-ChildItem $BOSH_BIN | ForEach-Object {
    Write-Host "Checking for $_.Name"
    $files.Remove($_.Name)
  }

  If ($files.Count -gt 0) {
    Write-Error "Unable to find the following binaries: $($files -join ',')"
    Exit 1
  }
}

function Verify-Acls {
  $windowsVersion = Get-OSVersion
  $expectedacls = New-Object System.Collections.ArrayList
  [void] $expectedacls.AddRange((
      "${env:COMPUTERNAME}\Administrator,Allow",
      "NT AUTHORITY\SYSTEM,Allow",
      "BUILTIN\Administrators,Allow",
      "CREATOR OWNER,Allow",
      "APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES,Allow",
      "NT SERVICE\TrustedInstaller,Allow"
  ))

  Write-Host "Adding ${windowsVersion} ACLs"
  # File in C:\Program Files\OpenSSH end up with the ACLs
  # "APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES,Allow".
  # so we add them here
  $expectedacls.Add("APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES,Allow")
  $expectedacls.Add("NT AUTHORITY\Authenticated Users,Allow")

  function Check-Acls {
      param([string]$path)

      $errCount = 0

      Get-ChildItem -Path $path -Recurse | ForEach-Object {
        $name = $_.FullName
        If (-Not ($_.Attributes -match "ReparsePoint")) {
          Get-Acl $name | Select-Object -ExpandProperty Access | ForEach-Object {
            $ident = ('{0},{1}' -f $_.IdentityReference, $_.AccessControlType).ToString()
            If (-Not $expectedacls.Contains($ident)) {
              $errCount += 1
              Write-Host "Error ($name): $ident"
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
}

function Verify-Services {
  If ( (Get-Service WinRM).Status -ne "Stopped") {
    $msg = "WinRM is not Stopped. It is {0}" -f $(Get-Service WinRM).Status
    Write-Error $msg
    Exit 1
  }

  $ssh_startype = "Automatic"

  If ( (Get-Service sshd).StartType -ne $ssh_startype) {
    $msg = "sshd service start type is not ${ssh_startype}. It is {0}" -f $(Get-Service sshd).StartType
    Write-Error $msg
    Exit 1
  }

  If ( (Get-Service ssh-agent).StartType -ne $ssh_startype) {
    $msg = "ssh-agent service start type is not ${ssh_startype}. It is {0}" -f $(Get-Service ssh-agent).StartType
    Write-Error $msg
    Exit 1
  }
}

function Verify-FirewallRules {
  function Get-FirewallProfile {
    param([string] $ProfileName)
    $firewall = (Get-NetFirewallProfile -Name $ProfileName)
    $result = "{0},{1},{2}" -f $ProfileName,$firewall.DefaultInboundAction,$firewall.DefaultOutboundAction
    return $result
  }

  function Test-FirewallProfile {
    param([string] $ProfileName)
    $firewall = (Get-FirewallProfile $ProfileName)
    Write-Host $firewall
    if ($firewall -ne "$ProfileName,Block,Allow") {
      Write-Host $firewall
      Write-Error "Unable to set $ProfileName Profile"
      Exit 1
    }
  }

  Test-FirewallProfile "public"
  Test-FirewallProfile "private"
  Test-FirewallProfile "domain"

}

function Verify-MetadataFirewallRule {
  $MetadataServerAllowRules = Get-NetFirewallRule -Enabled True -Direction Outbound | Get-NetFirewallAddressFilter | Where-Object -FilterScript { $_.RemoteAddress -Eq '169.254.169.254' }
  If ($null -Ne $MetadataServerAllowRules) {
    $RuleNames = $MetadataServerAllowRules | ForEach-Object { $_.InstanceID }
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
}

function Verify-InstalledFeatures {
  function Assert-IsInstalled {
      param (
          [Parameter(Mandatory)]
          [string] $feature
      )
      If (!(Get-WindowsFeature $feature).Installed) {
      Write-Error "Failed to find $feature"
      Exit 1
    } else {
      Write-Host "Found $feature feature"
    }
  }
  function Assert-IsNotInstalled {
      param (
          [Parameter(Mandatory)]
          [string] $feature
      )
      If (!(Get-WindowsFeature $feature).Installed) {
      Write-Host "Feature $feature is not installed"
    } else {
      Write-Error "Feature $feature is installed"
      Exit 1
    }
  }

  Assert-IsInstalled "Containers"
  Assert-IsNotInstalled "Windows-Defender"
}

function Verify-ProvisionerDeleted {
  $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
  $user = "Provisioner"
  $existing = $adsi.Children | Where-Object {$_.SchemaClassName -eq 'user' -and $_.Name -eq $user }
  if ($null -eq $existing) {
    Write-Host "$user user is deleted"
  } else {
    Write-Error "$user user still exists. Please run 'Remove-Account -User $user'"
    Exit 1
  }
}

function Verify-NetBIOSDisabled {
  $DisabledNetBIOS = $false
  $nbtstat = nbtstat.exe -n
  "results for nbtstat: $nbtstat"

  $nbtstat | ForEach-Object {
    $DisabledNetBIOS = $DisabledNetBIOS -or $_ -like '*No names in cache*'
  }
}

function Verify-AgentBehavior {
  $agent = Get-Service | Where-Object { $_.Name -eq 'bosh-agent' }
  if ($null -eq $agent) {
    Write-Error "Missing service: bosh-agent"
    Exit 1
  }
  if ($agent.StartType -ne "Automatic") {
    Write-Error "verify-agent-start-type: bosh-agent start type is not 'Automatic' got: '$($agent.StartType.ToString())'"
    Exit 1
  }

  $RegPath="HKLM:\SYSTEM\CurrentControlSet\Services\bosh-agent"

  if ((Get-ItemProperty $RegPath).DelayedAutostart -ne 1) {
    Write-Error "verify-agent-start-type: Expected DelayedAutostart to equal 1"
    Exit 1
  }

  $ServicesPipeTimeoutPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
  if ((Get-ItemProperty $ServicesPipeTimeoutPath).ServicesPipeTimeout -ne 60000) {
    Write-Error "Error: expected ServicesPipeTimeout to equal 60s"
    Exit 1
  }

  if ((Get-Service wuauserv).Status -ne "Stopped") {
    Write-Error "Error: expected wuauserv service to be Stopped"
    Exit 1
  }

  $StartType = (Get-Service wuauserv).StartType
  if ($StartType -ne "Disabled") {
    Write-Host "Warning: wuauserv service StartType is not disabled: ${StartType}"
  }
}

function Verify-RandomPassword {
  secedit /configure /db secedit.sdb /cfg c:\var\vcap\jobs\check-system\inf\security.inf

  Add-Type -AssemblyName System.DirectoryServices.AccountManagement
  $ComputerName=hostname
  $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)

  $config = Get-Config
  $DefaultUsername = $config.default_username
  $DefaultPassword = $config.default_password
  if ($DS.ValidateCredentials($DefaultUsername, $DefaultPassword)) {
      Write-Error "$DefaultUsername password was not randomized"
      Exit 1
  }
}

function Verify-NTPSync {
  Write-Host "Verifying NTP sync works correctly"
  w32tm /query /configuration

  Set-Date -Date (Get-Date).AddHours(-8)
  $OutOfSyncTime = Get-Date

  $TimeSetCorrectly = $false

  for ($i = 0; $i -lt 10; $i++) {
    Sleep 1

    w32tm /resync /rediscover
    w32tm /resync

    if ((Get-Date) -le $OutOfSyncTime) {
      Write-Host "Time not reset correctly via NTP on attempt $($i+1) of 10: $(Get-Date) less than or equal to $OutOfSyncTime"
    } else {
      $TimeSetCorrectly = $true
      break
    }
  }

  if (-not $TimeSetCorrectly) {
    Write-Error "Time not reset correctly via NTP after 10 attempts"
    Exit 1
  }
}

function Verify-NoDocker {
  try {
    docker ps
  } catch {
    Write-Host "Docker is not installed"
    return
  }

  Write-Error "Docker is installed. It shouldn't be!"
  Exit 1
}

function Verify-PSVersion5 {
  $PSMajorVersion = $PSVersionTable.PSVersion.Major

  if ($PSMajorVersion -lt 5) {
    Write-Error "PowerShell Major version is $PSMajorVersion. It should be at least 5"
    Exit 1
  }

  Write-Host "PowerShell is up to date: Version is: $($PSVersionTable.PSVersion)"
}

function Verify-VersionFile {
  $VersionFileExists = Test-Path "C:\\var\\vcap\\bosh\\etc\\stemcell_version" -PathType Leaf

  if (-Not $VersionFileExists) {
    Write-Error "Version file does not exist at path C:\\var\\vcap\\bosh\\etc\\stemcell_version"
    Exit 1
  }

  Write-Host "Version file exists at path C:\\var\\vcap\\bosh\\etc\\stemcell_version"
}

function Verify-HyperVIsEnabled {

  $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V

  if ($feature.State -ne "Enabled") {
    Write-Error "Hyper-V is NOT enabled"
    Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
    Exit 1
  }

  Write-Host "Hyper-V is enabled"
}

function Verify-TimeZone {
  # something about GCP
  $timezone = Get-TimeZone
  if ($timezone.Id -ne "UTC") {
    Write-Error "Timezone is $($timezone.Id), but should be: UTC"
    Exit 1
  }
}

Verify-LGPO
Verify-Dependencies
Verify-Acls
Verify-Services
Verify-FirewallRules
Verify-MetadataFirewallRule
Verify-InstalledFeatures
Verify-ProvisionerDeleted
Verify-NetBIOSDisabled
Verify-AgentBehavior
Verify-RandomPassword
Verify-NTPSync
Verify-NoDocker
Verify-PSVersion5
Verify-VersionFile
Verify-TimeZone

Import-Module C:\var\vcap\packages\pester\Pester\Pester.psd1
$pesterResults = Invoke-Pester $PSScriptRoot/AuditPolicies.Tests.ps1 -PassThru
if ($pesterResults.FailedCount -gt 0)
{
  Exit 1
}

Exit 0
