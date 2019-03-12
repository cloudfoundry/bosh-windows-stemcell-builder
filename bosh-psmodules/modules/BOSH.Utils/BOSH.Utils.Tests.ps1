#We remove multiple module that import BOSH.Utils
Remove-Module -Name BOSH.WinRM -ErrorAction Ignore
Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Remove-Module -Name BOSH.AutoLogon -ErrorAction Ignore

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
        Remove-Item -Path $KeyPath -ErrorAction SilentlyContinue
    }
}

Describe "Restore-RegistryState" {
    BeforeEach {
        Mock Remove-ItemProperty {}
        Mock Set-ItemProperty {}
        Mock Remove-Item {}
    }
    It "restores the registry by deleting a registry key created by the test" {
        Restore-RegistryState -KeyExists $false -KeyPath "HKLM:\Some registry key"

        Assert-MockCalled Remove-Item -Times 1 -Scope It -ParameterFilter { $Path -eq "HKLM:\Some registry key" }
        Assert-MockCalled Remove-ItemProperty -Times 0 -Scope It
        Assert-MockCalled Set-ItemProperty -Times 0 -Scope It
    }

    It "restores the registry by deleting a registry value created by the test" {
        Restore-RegistryState -KeyExist $true -KeyPath "HKLM:\Some registry key" -ValueName "SomeValue"

        Assert-MockCalled Remove-Item -Times 0 -Scope It
        Assert-MockCalled Remove-ItemProperty -Times 1 -Scope It -ParameterFilter { $Path -eq "HKLM:\Some registry key" -and $Name -eq "SomeValue"}
        Assert-MockCalled Set-ItemProperty -Times 0 -Scope It
    }

    It "restores the registry by restoring a registry data modified by the test" {
        Restore-RegistryState -KeyExist $true -KeyPath "HKLM:\Some registry key" -ValueName "SomeValue" -ValueData "Some Data"
        Restore-RegistryState -KeyExist $true -KeyPath "HKLM:\Some dword reg key" -ValueName "SomeDwordValye" -ValueData 85432

        Assert-MockCalled Remove-Item -Times 0 -Scope It
        Assert-MockCalled Remove-ItemProperty -Times 0 -Scope It
        Assert-MockCalled Set-ItemProperty -Times 1 -Scope It -ParameterFilter { $Path -eq "HKLM:\Some registry key" -and $Name -eq "SomeValue" -and $Value -eq "Some Data" }
        Assert-MockCalled Set-ItemProperty -Times 1 -Scope It -ParameterFilter { $Path -eq "HKLM:\Some dword reg key" -and $Name -eq "SomeDwordValye" -and $Value -eq 85432 }
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

Describe "Disable-TLS11" {
    It "Disables the use of TLS 1.0" {
        $serverPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
        $serverPathExists = Test-Path -Path $serverPath

        $oldServerDisabledValue =  (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'DisabledByDefault'
        $oldServerValue = (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'Enabled'

        $clientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
        $clientPathExists = Test-Path -Path $clientPath

        $oldClientEnabledValue = (Get-ItemProperty -path $clientPath -ErrorAction SilentlyContinue).'Enabled'
        $oldClientDisabledValue = (Get-ItemProperty -path $clientPath -ErrorAction SilentlyContinue).'DisabledByDefault'

        { Disable-TLS11 } | Should Not Throw

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

Describe "Enable-TLS12" {
    It "Disables the use of TLS 1.0" {
        $serverPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
        $serverPathExists = Test-Path -Path $serverPath

        $oldServerValue = (Get-ItemProperty -path $serverPath -ErrorAction SilentlyContinue).'Enabled'

        $clientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
        $clientPathExists = Test-Path -Path $clientPath

        $oldClientEnabledValue = (Get-ItemProperty -path $clientPath -ErrorAction SilentlyContinue).'Enabled'

        { Enable-TLS12 } | Should Not Throw

        (Get-ItemProperty -Path $serverPath).'Enabled' | Should Be "1"

        (Get-ItemProperty -Path $clientPath).'Enabled' | Should Be "1"

        Restore-RegistryState -KeyExists $serverPathExists -KeyPath $serverPath -ValueName 'Enabled' -ValueData $oldServerValue

        Restore-RegistryState -KeyExists $clientPathExists -KeyPath $clientPath -ValueName 'Enabled' -ValueData $oldClientValue
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

Describe "Get-OSVersion" {
    BeforeEach {
        Mock Write-Log { } -ModuleName BOSH.Utils
    }

    It "Correctly detects Windows 2012R2" {
        Mock Get-OSVersionString { "6.3.9600.68" } -ModuleName BOSH.Utils
        $actualOSVersion = $null

        { Get-OSVersion | Set-Variable -Name "actualOSVersion" -Scope 1 } | Should -Not -Throw
        $actualOsVersion | Should -eq "windows2012R2"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found OS version: Windows 2012R2" } -ModuleName BOSH.Utils
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It -ModuleName BOSH.Utils
    }

    It "Correctly detects Windows 1709" {
        Mock Get-OSVersionString { "10.0.16299.233" } -ModuleName BOSH.Utils
        $actualOSVersion = $null

        { Get-OSVersion | Set-Variable -Name "actualOSVersion" -Scope 1 } | Should -Not -Throw
        $actualOsVersion | Should -eq "windows2016"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found OS version: Windows 1709" } -ModuleName BOSH.Utils
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It -ModuleName BOSH.Utils
    }

    It "Correctly detects Windows 1803" {
        Mock Get-OSVersionString { "10.0.17134.420" } -ModuleName BOSH.Utils
        $actualOSVersion = $null

        { Get-OSVersion | Set-Variable -Name "actualOSVersion" -Scope 1 } | Should -Not -Throw
        $actualOsVersion | Should -eq "windows2016"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found OS version: Windows 1803" } -ModuleName BOSH.Utils
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It -ModuleName BOSH.Utils
    }

    It "Correctly detects Windows 2019" {
        Mock Get-OSVersionString { "10.0.17763.410" } -ModuleName BOSH.Utils
        $actualOSVersion = $null

        { Get-OSVersion | Set-Variable -Name "actualOSVersion" -Scope 1 } | Should -Not -Throw
        $actualOsVersion | Should -eq "windows2019"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found OS version: Windows 2019" } -ModuleName BOSH.Utils
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It -ModuleName BOSH.Utils
    }

    It "Throws an exception if a valid OS is not detected" {
        Mock Get-OSVersionString { "01.23.456.789" } -ModuleName BOSH.Utils

        { Get-OSVersion } | Should -Throw "invalid OS detected"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "invalid OS detected" } -ModuleName BOSH.Utils
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It -ModuleName BOSH.Utils
    }
}

Describe "Get-WinRMConfig" {
    It "makes a request for winrm config, returns stdout" {
        Mock Invoke-Expression {
            "Lots of winrm config"
        } -ModuleName BOSH.Utils

        $output = ""
        { Get-WinRMConfig | Set-Variable -Name "output" -Scope 1 } | Should -Not -Throw

        $output | Should -eq "Lots of winrm config"

        Assert-MockCalled Invoke-Expression -Times 1 -Scope It `
            -ParameterFilter { $Command -and $Command -eq "winrm get winrm/config" } -ModuleName BOSH.Utils
    }

    It "throws a descriptive failure when winrm config is unavailable" {
        Mock Invoke-Expression {
            Write-Error "Some error output"
        } -ModuleName BOSH.Utils

        $output = ""
        { Get-WinRMConfig | Set-Variable -Name "output" -Scope 1 } | `
            Should -Throw "Failed to get WinRM config: Some error output"

        $output | Should -eq ""
    }
}

Describe "Set-ProxySettings" {
    It "sets the Internet Explorer proxy settings" {
        function Compare-Array {
            $($args[0] -join ",") -eq $($args[1] -join ",")
        }

        Mock Set-ItemProperty {
            "Property set"
        } -ModuleName BOSH.Utils

        { Set-ProxySettings "http-proxy" "https-proxy" "bypass-list" } | Should Not Throw

        [string] $start =  [System.Text.Encoding]::ASCII.GetString([byte[]](70, 0, 0, 0, 25, 0, 0, 0, 3, 0, 0, 0, 29, 0, 0, 0 ), 0, 16);
        [string] $endproxy = [System.Text.Encoding]::ASCII.GetString([byte[]]( 233, 0, 0, 0 ), 0, 4);
        [string] $end = [System.Text.Encoding]::ASCII.GetString([byte[]]( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), 0, 36);

        [string] $text = "$($start)http=http-proxy;https=https-proxy$($endproxy)bypass-list$($end)";
        [byte[]] $data = [System.Text.Encoding]::ASCII.GetBytes($text);

        Assert-MockCalled Set-ItemProperty -Times 1 -ModuleName BOSH.Utils -Scope It `
            -ParameterFilter {
            $Path -eq "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -and
            $Name -eq "DefaultConnectionSettings" -and
            (Compare-Array $Value $data)
        }
    }

    It "exits when the registry can't be set or there's an error because the arguments are wrong" {
        Mock Set-ItemProperty {
            Write-Error "Property not set"
        } -ModuleName BOSH.Utils


        { Set-ProxySettings "http-proxy" "https-proxy" "bypass-list" } | Should -Throw "Failed to set proxy settings: Property not set"
    }
}

Describe "Clear-ProxySettings"  {
    BeforeEach {
        Mock Write-Log { } -ModuleName BOSH.Utils
    }

    It "Should remove proxy settings if they were set" {
        $regKeyConnections = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
        Set-ItemProperty -Path $regKeyConnections -Name "DefaultConnectionSettings" -Value "test-value" -ErrorVariable err 2>&1 | Out-Null

        $set_proxy = & cmd.exe /c "netsh winhttp set proxy proxy-server=`"127.0.0.1`""

        Clear-ProxySettings

        $item=Get-Item $regKeyConnections

        #DefaultConnectionSettings is actually added to a "Property" object
        $item.Property | Should Be $null

        #We need to pipe the netsh command through Out-String in order to convert its output into a proper string
        $output= (netsh winhttp show proxy) | Out-String
        $output | Should -BeLike "*Direct access (no proxy server)*"
        Assert-MockCalled Write-Log -Times 1 -ModuleName BOSH.Utils -Scope It -ParameterFilter { $Message -eq "Cleared proxy settings: $output" }
    }

    It "Should not error if no proxy settings are found" {
        Clear-ProxySettings

        Assert-MockCalled Write-Log -Times 1 -ModuleName BOSH.Utils -Scope It -ParameterFilter { $Message -eq "No proxy settings set. There is nothing to clear." }
    }
}

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
