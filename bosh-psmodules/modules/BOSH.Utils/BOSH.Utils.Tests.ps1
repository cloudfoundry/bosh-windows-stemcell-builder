Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ./BOSH.Utils.psm1

#As of now, this function only supports DWords and Strings.
function Restore-RegistryState {
    param(
        [bool]$KeyExists,
        [String]$KeyPath,
        [String]$ValueName,
        [PSObject]$ValueData
    )
    if ($KeyExists) {
        if ($ValueData -eq $null) {
            Remove-ItemProperty -path $KeyPath -Name $ValueName
        } else {
            Set-ItemProperty -path $KeyPath -Name $ValueName -Value $ValueData
        }
    } else {
        Remove-Item -Path $KeyPath
    }
}

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Open-Zip" {
    BeforeEach {
        $outPath=(New-TempDir)
    }

    AfterEach {
        Remove-Item -Recurse -Force $outPath
    }

    Context "when zipFile is not provided" {
        It "throws" {
            { Open-Zip } | Should Throw "Provide a ZipFile to extract"
        }
    }
    Context "when output file already exists" {
        It "does not throw" {
            New-Item -Path $outPath -Name "file.txt" -ItemType "file" -Value "Hello"
            { Open-Zip -ZipFile "./example.zip" -OutPath $outPath } | Should Not Throw
            Get-Content (Join-Path $outPath "file.txt") | Should Be "file"
        }
    }
    Context "when OutPath is not provided" {
        It "throws" {
            { Open-Zip -ZipFile "./example.zip" } | Should Throw "Provide an OutPath for extract"
        }
    }
    It "extracts Zip file" {
        Open-Zip -ZipFile "./example.zip" -OutPath $outPath
        $file = (Join-Path $outPath "file.txt")
        Test-Path $file | Should be $True
    }
}

Describe "Get-Log" {
    Context "when missing log file" {
        It "throws" {
            $dir = (New-TempDir)
            $logFile = (Join-Path $dir "log.log")
            { Get-Log -LogFile $logFile } | Should Throw "Missing log file: $logFile"
        }
    }
}

Describe  "Protect-Dir" {
    BeforeEach {
        $aclDir=(New-TempDir)
        New-Item -Path $aclDir -ItemType Directory -Force

        cacls.exe $aclDir /T /E /P "BUILTIN\Users:F"
        $LASTEXITCODE | Should Be 0
        cacls.exe $aclDir /T /E /P "BUILTIN\IIS_IUSRS:F"
        $LASTEXITCODE | Should Be 0
    }

    AfterEach {
        Remove-Item -Recurse -Force $aclDir
    }

    Context "when not provided a directory" {
        It "throws" {
            { Protect-Dir } | Should Throw "Provide a directory to set ACL on"
        }
    }

    It "sets the correct ACLs on the provided directory" {
        { Protect-Dir -path $aclDir } | Should Not Throw

        $acl = (Get-Acl $aclDir)
        $acl.Owner | Should Be "BUILTIN\Administrators"
        $acl.Access | where { $_.IdentityReference -eq "BUILTIN\Users" } | Should BeNullOrEmpty
        $acl.Access | where { $_.IdentityReference -eq "BUILTIN\IIS_IUSRS" } | Should BeNullOrEmpty
        $adminAccess = ($acl.Access | where { $_.IdentityReference -eq "BUILTIN\Administrators" })
        $adminAccess | Should Not BeNullOrEmpty
        $adminAccess.FileSystemRights | Should Be "FullControl"
    }

    Context "when inheritance is disabled" {
        It "disables ACL inheritance on the provided directory " {
            { Protect-Dir -path $aclDir -disableInheritance $True } | Should Not Throw

            (Get-Acl $aclDir).AreAccessRulesProtected | Should Be $True
        }
    }
}

Describe "Disable-RC4" {
    It "Disables the use of RC4 Cipher" {
        $rc4_128Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128"
        $rc4_128PathExists = Test-Path -Path $rc4_128Path
        $oldRC4_128Value = (Get-ItemProperty -path $rc4_128Path -ErrorAction SilentlyContinue).'Enabled'

        $rc4_40Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128"
        $rc4_40PathExists = Test-Path -Path $rc4_40Path
        $oldRC4_40Value = (Get-ItemProperty -path $rc4_40Path -ErrorAction SilentlyContinue).'Enabled'

        $rc4_56Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128"
        $rc4_56PathExists = Test-Path -Path $rc4_56Path
        $oldRC4_56Value = (Get-ItemProperty -path $rc4_56Path -ErrorAction SilentlyContinue).'Enabled'

        { Disable-RC4 } | Should Not Throw

        (Get-ItemProperty -Path $rc4_128Path).'Enabled' | Should Be "0"
        (Get-ItemProperty -Path $rc4_40Path).'Enabled' | Should Be "0"
        (Get-ItemProperty -Path $rc4_56Path).'Enabled' | Should Be "0"

        Restore-RegistryState -KeyExists $rc4_128PathExists -KeyPath $rc4_128Path -ValueName 'Enabled' -ValueData $oldRC4_128Value
        Restore-RegistryState -KeyExists $rc4_40PathExists -KeyPath $rc4_40Path -ValueName 'Enabled' -ValueData $oldRC4_40Value
        Restore-RegistryState -KeyExists $rc4_56PathExists -KeyPath $rc4_56Path -ValueName 'Enabled' -ValueData $oldRC4_56Value
    }
}

Describe "Disable-TLS1" {
    It "Disables the use of TLS 1.0" {
        $serverPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
        $serverPathExists = Test-Path -Path $serverPath

        $oldServerEnabledValue = (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'Enabled'
        $oldServerDisabledValue =  (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'DisabledByDefault'
        $oldServerValue = (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'Enabled'

        $clientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'
        $clientPathExists = Test-Path -Path $clientPath

        $oldClientEnabledValue = (Get-ItemProperty -path $clientPath -ErrorAction SilentlyContinue).'Enabled'
        $oldClientDisabledValue = (Get-ItemProperty -path $clientPath -ErrorAction SilentlyContinue).'DisabledByDefault'

        { Disable-TLS1 } | Should Not Throw

        (Get-ItemProperty -Path $serverPath).'Enabled' | Should Be "0"
        (Get-ItemProperty -Path $serverPath).'DisabledByDefault' | Should Be "1"

        (Get-ItemProperty -Path $clientPath).'Enabled' | Should Be "0"
        (Get-ItemProperty -Path $clientPath).'DisabledByDefault' | Should Be "1"

        Restore-RegistryState -KeyExists $serverPathExists -KeyPath $serverPath -ValueName 'Enabled' -ValueData $oldServerValue
        Restore-RegistryState -KeyExists $serverPathExists -KeyPath $serverPath -ValueName 'DisabledByDefault' -ValueData $oldServerDisabledValue

        Restore-RegistryState -KeyExists $clientPathExists -KeyPath $clientPath -ValueName 'Enabled' -ValueData $oldClientValue
        Restore-RegistryState -KeyExists $clientPathExists -KeyPath $clientPath -ValueName 'DisabledByDefault' -ValueData $oldClientDisabledValue
    }
}

Describe "Disable-3DES" {
    It "Disables birthday attacks against 64 bit block TLS ciphers" {
        $registryPath = 'hklm:\system\currentcontrolset\control\securityproviders\schannel\ciphers\triple des 168'
        $tripleDESPathExists = Test-Path $registryPath
        $oldDESValue = (Get-ItemProperty -path $registryPath -ErrorAction SilentlyContinue).'Enabled'

        { Disable-3DES } | Should Not Throw

        (Get-ItemProperty -path $registryPath).'Enabled' | Should Be "0"

        Restore-RegistryState -KeyExists $tripleDESPathExists -KeyPath $registryPath -ValueName 'Enabled' -ValueData $oldDESValue
    }
}

Describe "Disable-DCOM" -Tag 'Focused' {
    It "Disables the use of DCOM" {
        $DCOMPath = 'HKLM:\Software\Microsoft\OLE'
        $oldDCOMValue = (Get-ItemProperty -Path $DCOMPath).'EnableDCOM'

        { Disable-DCOM } | Should Not Throw

        (Get-ItemProperty -Path $DCOMPath).'EnableDCOM' | Should Be "N"
        Set-ItemProperty -Path $DCOMPath -Name 'EnableDCOM' -Value $oldDCOMValue

        Restore-RegistryState -KeyExists $true -KeyPath $DCOMPath -ValueName 'EnableDCOM' -ValueData $oldDCOMValue
    }
}

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
