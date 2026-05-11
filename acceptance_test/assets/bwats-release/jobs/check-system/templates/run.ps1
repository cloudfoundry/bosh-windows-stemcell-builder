$ErrorActionPreference = "Stop";
$outfile = "C:\var\vcap\sys\log\check-system\combined-output.log"

function Get-Config {
    $configPath = Join-Path $PSScriptRoot "config.json"
    Write-Output "Loading '$configPath'"
    $config = Get-Content $configPath -raw | ConvertFrom-Json
    Write-Output "Loaded '$configPath'"
    return $config
}

function Test-LGPO {
    Write-Output "Running this function Test-LGPO"
    Write-Output "Verifying that expected policies have been applied"

    Invoke-Cmd "lgpo /q /b $PSScriptRoot"
    $LgpoDir = "$PSScriptRoot\" + (Get-ChildItem $PSScriptRoot -Directory | Where-Object { $_.Name -match "{*}" } | Select-Object -First 1).Name

    $OutputDir = "$PSScriptRoot\lgpo_test"
    New-Item -ItemType Directory -Path $OutputDir -Force

    Invoke-Cmd "lgpo /q /parse /m `"$LgpoDir\DomainSysvol\GPO\Machine\registry.pol`"" > "$OutputDir\machine_registry.unedited.txt"
    Get-Content "$OutputDir\machine_registry.unedited.txt" | Select-Object -Skip 3 > "$OutputDir\machine_registry.txt"

    Invoke-Cmd "lgpo /q /parse /u `"$LgpoDir\DomainSysvol\GPO\User\registry.pol`"" > "$OutputDir\user_registry.unedited.txt"
    Get-Content "$OutputDir\user_registry.unedited.txt" | Select-Object -Skip 3 > "$OutputDir\user_registry.txt"

    Copy-Item "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv" "$OutputDir"
    $Csv = Import-Csv "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv"
    $Include = $Csv[0].psobject.properties | Select-Object -ExpandProperty Name -Skip 1
    $Csv | Select-Object $Include | export-csv "$OutputDir\audit.csv" -NoTypeInformation

    Copy-Item "$LgpoDir\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" "$OutputDir"

    function Compare-LGPOPolicies {
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
        } else {
            return 0
        }
    }

    $OsVersion = Get-OSVersion
    switch ($OsVersion) {
        "windows2019" {
            $TestDir = "$PSScriptRoot\..\test-2019"
        }
    }

    $ErrorActionPreference = "Continue"
    $errorCount = 0
    $result = Compare-LGPOPolicies "$OutputDir\machine_registry.txt" "$TestDir\machine_registry.txt" "\n\n"
    $errorCount += $result
    $result = Compare-LGPOPolicies "$OutputDir\user_registry.txt" "$TestDir\user_registry.txt" "\n\n"
    $errorCount += $result
    $result = Compare-LGPOPolicies "$OutputDir\GptTmpl.inf" "$TestDir\GptTmpl.inf" "\n"
    $errorCount += $result
    $result = Compare-LGPOPolicies "$OutputDir\audit.csv" "$TestDir\audit.csv" "\n"
    $errorCount += $result
    $ErrorActionPreference = "Stop"

    if (-not $errorCount -eq 0) {
        Write-Error "LGPO checks failed"
        return 1
    }
}

function Test-Dependencies {
    $BOSH_BIN = "C:\\var\\vcap\\bosh\\bin"
    Write-Output "Checking $BOSH_BIN dependencies"

    $files = New-Object System.Collections.ArrayList
    [void] $files.AddRange((
    "bosh-blobstore-s3.exe",
    "bosh-blobstore-dav.exe",
    "job-service-wrapper.exe"
    ))

    Get-ChildItem $BOSH_BIN | ForEach-Object {
        Write-Output "Checking for $_.Name"
        $files.Remove($_.Name)
    }

    If ($files.Count -gt 0) {
        Write-Error "Unable to find the following binaries: $( $files -join ',' )"
        Exit 1
    }
}

function Test-Acls {
    $expectedacls = New-Object System.Collections.ArrayList
    [void] $expectedacls.AddRange((
    "${env:COMPUTERNAME}\Administrator,Allow",
    "NT AUTHORITY\SYSTEM,Allow",
    "BUILTIN\Administrators,Allow",
    "CREATOR OWNER,Allow",
    "APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES,Allow",
    "NT SERVICE\TrustedInstaller,Allow",
    "APPLICATION PACKAGE AUTHORITY\ALL RESTRICTED APPLICATION PACKAGES,Allow",
    "NT AUTHORITY\Authenticated Users,Allow"
    ))

    function Test-FolderAcls {
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
    $errCount += Test-FolderAcls "C:\var"
    $errCount += Test-FolderAcls "C:\bosh"
    $errCount += Test-FolderAcls "C:\Windows\Panther\Unattend"
    $errCount += Test-FolderAcls "C:\Program Files\OpenSSH"

    function Test-BoshDirAcls {
        param([string]$path)

        $writeBits = [System.Security.AccessControl.FileSystemRights]::WriteData -bor
                     [System.Security.AccessControl.FileSystemRights]::AppendData -bor
                     [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
                     [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
                     [System.Security.AccessControl.FileSystemRights]::Delete -bor
                     [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
                     [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                     [System.Security.AccessControl.FileSystemRights]::TakeOwnership

        $errCount = 0
        @($path) + (Get-ChildItem -Path $path -Recurse | Select-Object -ExpandProperty FullName) | ForEach-Object {
            $name = $_
            If (-Not ((Get-Item $name).Attributes -match "ReparsePoint")) {
                Get-Acl $name | Select-Object -ExpandProperty Access |
                    Where-Object { $_.IdentityReference -eq "NT AUTHORITY\Authenticated Users" -and $_.AccessControlType -eq "Allow" } |
                    ForEach-Object {
                        if ($_.FileSystemRights -band $writeBits) {
                            $errCount += 1
                            Write-Host "Error ($name): Authenticated Users has write access: $($_.FileSystemRights)"
                        }
                    }
            }
        }
        return $errCount
    }

    $errCount += Test-BoshDirAcls "C:\bosh"
    $errCount += Test-BoshDirAcls "C:\var\vcap\bosh\bin"

    if ($errCount -ne 0) {
        Write-Error "FAILED: $errCount"
        Exit 1
    }
}

function Test-Services {
    If ((Get-Service WinRM).Status -ne "Stopped") {
        $msg = "WinRM is not Stopped. It is {0}" -f $( Get-Service WinRM ).Status
        Write-Error $msg
        Exit 1
    }

    $ssh_startype = "Automatic"

    If ((Get-Service sshd).StartType -ne $ssh_startype) {
        $msg = "sshd service start type is not ${ssh_startype}. It is {0}" -f $( Get-Service sshd ).StartType
        Write-Error $msg
        Exit 1
    }

    If ((Get-Service ssh-agent).StartType -ne $ssh_startype) {
        $msg = "ssh-agent service start type is not ${ssh_startype}. It is {0}" -f $( Get-Service ssh-agent ).StartType
        Write-Error $msg
        Exit 1
    }
}

function Test-FirewallRules {
    function Get-FirewallProfile {
        param([string] $ProfileName)
        $firewall = (Get-NetFirewallProfile -Name $ProfileName)
        $result = "{0},{1},{2}" -f $ProfileName, $firewall.DefaultInboundAction, $firewall.DefaultOutboundAction
        return $result
    }

    function Test-FirewallProfile {
        param([string] $ProfileName)
        $firewall = (Get-FirewallProfile $ProfileName)
        Write-Output $firewall
        if ($firewall -ne "$ProfileName,Block,Allow") {
            Write-Output $firewall
            Write-Error "Unable to set $ProfileName Profile"
            Exit 1
        }
    }

    Test-FirewallProfile "public"
    Test-FirewallProfile "private"
    Test-FirewallProfile "domain"
}

function Test-MetadataFirewallRule {
    $MetadataServerAllowRules = Get-NetFirewallRule -Enabled True -Direction Outbound | Get-NetFirewallAddressFilter | Where-Object -FilterScript { $_.RemoteAddress -Eq '169.254.169.254' }

    If ($null -Ne $MetadataServerAllowRules) {
        $RuleNames = $MetadataServerAllowRules | ForEach-Object { $_.InstanceID }
        If ($RuleNames.Count -ne 2) {
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

function Test-InstalledFeatures {
    function Assert-IsInstalled {
        param (
            [Parameter(Mandatory)]
            [string] $feature
        )
        If (!(Get-WindowsFeature $feature).Installed) {
            Write-Error "Failed to find $feature"
            Exit 1
        } else {
            Write-Output "Found $feature feature"
        }
    }
    function Assert-IsNotInstalled {
        param (
            [Parameter(Mandatory)]
            [string] $feature
        )
        If (!(Get-WindowsFeature $feature).Installed) {
            Write-Output "Feature $feature is not installed"
        } else {
            Write-Error "Feature $feature is installed"
            Exit 1
        }
    }

    Assert-IsInstalled "Containers"
    Assert-IsNotInstalled "Windows-Defender"
}

function Test-ProvisionerDeleted {
    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
    $user = "Provisioner"
    $existing = $adsi.Children | Where-Object { $_.SchemaClassName -eq 'user' -and $_.Name -eq $user }
    if ($null -eq $existing) {
        Write-Output "$user user is deleted"
    } else {
        Write-Error "$user user still exists. Please run 'Remove-Account -User $user'"
        Exit 1
    }
}

function Test-NetBIOSDisabled {
    $DisabledNetBIOS = $false
    $nbtstat = nbtstat.exe -n
    "results for nbtstat: $nbtstat"

    $nbtstat | ForEach-Object {
        $DisabledNetBIOS = $DisabledNetBIOS -or $_ -like '*No names in cache*'
    }
}

function Test-AgentBehavior {
    $agent = Get-Service | Where-Object { $_.Name -eq 'bosh-agent' }
    if ($null -eq $agent) {
        Write-Error "Missing service: bosh-agent"
        Exit 1
    }
    if ($agent.StartType -ne "Automatic") {
        Write-Error "test-agent-start-type: bosh-agent start type is not 'Automatic' got: '$($agent.StartType.ToString() )'"
        Exit 1
    }

    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\bosh-agent"

    if ((Get-ItemProperty $RegPath).DelayedAutostart -ne 1) {
        Write-Error "test-agent-start-type: Expected DelayedAutostart to equal 1"
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
        Write-Output "Warning: wuauserv service StartType is not disabled: ${StartType}"
    }
}

function Test-RandomPassword {
    secedit /configure /db secedit.sdb /cfg c:\var\vcap\jobs\check-system\inf\security.inf

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $ComputerName = hostname
    $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine', $ComputerName)

    $config = Get-Config
    $DefaultUsername = $config.default_username
    $DefaultPassword = $config.default_password
    if ( $DS.ValidateCredentials($DefaultUsername, $DefaultPassword)) {
        Write-Error "$DefaultUsername password was not randomized"
        Exit 1
    }
}

function Test-NTPSync {
    Write-Output "Verifying NTP sync works correctly"
    w32tm /query /configuration

    Set-Date -Date (Get-Date).AddHours(-8)
    $OutOfSyncTime = Get-Date

    $TimeSetCorrectly = $false

    for ($i = 0; $i -lt 10; $i++) {
        Sleep 1

        w32tm /resync /rediscover
        w32tm /resync

        if ((Get-Date) -le $OutOfSyncTime) {
            Write-Output "Time not reset correctly via NTP on attempt $( $i + 1 ) of 10: $( Get-Date ) less than or equal to $OutOfSyncTime"
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

function Test-NoDocker {
    try {
        docker ps
    } catch {
        Write-Output "Docker is not installed"
        return
    }

    Write-Error "Docker is installed. It shouldn't be!"
    Exit 1
}

function Test-PSVersion5 {
    $PSMajorVersion = $PSVersionTable.PSVersion.Major

    if ($PSMajorVersion -lt 5) {
        Write-Error "PowerShell Major version is $PSMajorVersion. It should be at least 5"
        Exit 1
    }

    Write-Output "PowerShell is up to date: Version is: $( $PSVersionTable.PSVersion )"
}

function Test-VersionFile {
    $VersionFileExists = Test-Path "C:\\var\\vcap\\bosh\\etc\\stemcell_version" -PathType Leaf

    if (-Not $VersionFileExists) {
        Write-Error "Version file does not exist at path C:\\var\\vcap\\bosh\\etc\\stemcell_version"
        Exit 1
    }

    Write-Output "Version file exists at path C:\\var\\vcap\\bosh\\etc\\stemcell_version"
}

function Test-HyperVIsEnabled {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V

    if ($feature.State -ne "Enabled") {
        Write-Error "Hyper-V is NOT enabled"
        Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
        Exit 1
    }

    Write-Output "Hyper-V is enabled"
}

function Test-TimeZone {
    $timezone = Get-TimeZone
    if ($timezone.Id -ne "UTC") {
        Write-Error "Timezone is $( $timezone.Id ), but should be: UTC"
        Exit 1
    }
}

function Test-AuditPolicies {
    $expectedAuditPolicies = @{
        'Credential Validation' = 'Success and Failure';
        'Security Group Management' = 'Success';
        'User Account Management' = 'Success and Failure';
        'Plug and Play Events' = 'Success';
        'Process Creation' = 'Success';
        'Account Lockout' = 'Failure';
        'Group Membership' = 'Success';
        'Logon' = 'Success and Failure';
        'Other Logon/Logoff Events' = 'Success and Failure';
        'Special Logon' = 'Success';
        'Detailed File Share' = 'Failure';
        'File Share' = 'Success and Failure';
        'Other Object Access Events' = 'Success and Failure';
        'Removable Storage' = 'Success and Failure';
        'Audit Policy Change' = 'Success';
        'Authentication Policy Change' = 'Success';
        'MPSSVC Rule-Level Policy Change' = 'Success and Failure';
        'Other Policy Change Events' = 'Failure';
        'Sensitive Privilege Use' = 'Success and Failure';
        'Other System Events' = 'Success and Failure';
        'Security State Change' = 'Success';
        'Security System Extension' = 'Success';
        'System Integrity' = 'Success and Failure';
    }


    $backupDirWithoutBackslashes = "$env:TMP/policyBackup-$([System.Guid]::NewGuid() )"
    $backupDir = [System.IO.Path]::GetFullPath($backupDirWithoutBackslashes)

    New-Item -ItemType Directory -Path $backupDir
    Invoke-Cmd "lgpo /q /b $backupDir"

    $backupPaths = (Get-ChildItem $backupDir)
    if ($backupPaths.Count -ne 1) {
        Write-Error "Expected exactly 1 backup directory, but found $( $backupPaths.Count )"
        Exit 1
    }

    $policyPath = "$backupDir\$( $backupPaths.Name )\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv"

    if (-not (Test-Path $policyPath)) {
        Write-Error "Audit policy file does not exist at: $policyPath"
        Exit 1
    }

    Write-Output "Loading actual policies from: $policyPath"
    $actualPolicies = Import-Csv $policyPath

    $failedTests = 0
    foreach ($policyName in $expectedAuditPolicies.keys) {
        $expectedValue = $expectedAuditPolicies[$policyName]
        $actualPolicy = $actualPolicies | Where-Object { $_.Subcategory -eq $policyName }

        Write-Output "Checking audit policy '$policyName' is set to '$expectedValue'..."
        if ($null -eq $actualPolicy -or $actualPolicy.Count -eq 0) {
            Write-Error "Audit policy subcategory '$policyName' should exist but was not found"
            $failedTests++
            continue
        }

        $actualValue = $actualPolicy.'Inclusion Setting'
        if ($actualValue -ne $expectedValue) {
            Write-Error "Audit policy '$policyName' is set to '$actualValue' but expected '$expectedValue'"
            $failedTests++
        } else {
            Write-Output "PASS: Audit policy '$policyName' is correctly set to '$expectedValue'"
        }

        if ($failedTests -gt 0) {
            Write-Error "Audit policies verification failed with $failedTests error(s)"
            Exit 1
        }
    }
}

function Invoke-Cmd {
    param(
        [string] $Command
    )
    Write-Output "Invoking command: $Command"
    $output = cmd /c $Command '2>&1'

    if ($LASTEXITCODE -ne 0) {
        Write-Error ($output -join "`n")
    }
    Write-Output ($output -join "`n")
}

$scriptBlock = {
    try {
        Write-Output "Starting Test Suite"

        Write-Output "`nTesting LGPO"
        Test-LGPO
        Write-Output "`nTesting Dependencies"
        Test-Dependencies
        Write-Output "`nTesting Acls"
        Test-Acls
        Write-Output "`nTesting Services"
        Test-Services
        Write-Output "`nTesting Firewall Rules"
        Test-FirewallRules
        Write-Output "`nTesting Metadata Firewall Rule"
        Test-MetadataFirewallRule
        Write-Output "`nTesting Installed Features"
        Test-InstalledFeatures
        Write-Output "`nTesting Provisioner Deleted"
        Test-ProvisionerDeleted
        Write-Output "`nTesting NetBIOS Disabled"
        Test-NetBIOSDisabled
        Write-Output "`nTesting Agent Behavior"
        Test-AgentBehavior
        Write-Output "`nTesting Random Password"
        Test-RandomPassword
        Write-Output "`nTesting NTP Sync"
        Test-NTPSync
        Write-Output "`nTesting No Docker"
        Test-NoDocker
        Write-Output "`nTesting PS Version 5"
        Test-PSVersion5
        Write-Output "`nTesting Version File"
        Test-VersionFile
        Write-Output "`nTesting Time Zone"
        Test-TimeZone
        Write-Output "`nTesting Audit Policies"
        Test-AuditPolicies

        Write-Output "Test Suite completed successfully"
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        Write-Host "ERROR: $($_.Exception.StackTrace)"
        Write-Host "ERROR: $($_.Exception.TargetSite)"
        Write-Host "ERROR: $($_.Exception.Data)"
        Write-Host "ERROR: $($_.Exception.HelpLink)"
        Write-Host "ERROR: $($_.Exception.Source)"
        Write-Host "ERROR: $($_.Exception.InnerException)"

        exit 1
    } finally {
        if (Test-Path "$outfile.utf16") {
            Get-Content "$outfile.utf16" | Set-Content -Encoding utf8 "$outfile"
        }
    }
}

& $scriptBlock *>&1 | Tee-Object -FilePath "$outfile.utf16"

Exit 0