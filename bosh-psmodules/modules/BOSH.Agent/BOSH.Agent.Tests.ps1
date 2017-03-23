Remove-Module -Name BOSH.Agent -ErrorAction Ignore
Import-Module ./BOSH.Agent.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Copy-Agent" {
    BeforeEach {
        $installDir=(New-TempDir)
        $boshDir = (Join-Path $installDir "bosh")
        $vcapDir = (Join-Path $installDir (Join-Path "var" (Join-Path "vcap" "bosh")))
        $agentZipPath = (Join-Path $PSScriptRoot (Join-Path "fixtures" "bosh-agent.zip"))
    }

    AfterEach {
        Remove-Item -Recurse -Force $installDir
    }

    Context "when installDir is not provided" {
        It "throws" {
            { Copy-Agent -agentZipPath $agentZipPath } | Should Throw "Provide a directory to install the BOSH agent"
        }
    }

    Context "when agentZipPath is not provided" {
        It "throws" {
            { Copy-Agent -installDir $installDir } | Should Throw "Provide the path to the BOSH agent zipfile"
        }
    }

    It "creates required directories" {
        { Copy-Agent -installDir $installDir -agentZipPath $agentZipPath } | Should Not Throw
        Test-Path $boshDir -PathType Container | Should Be $True
        Test-Path $vcapDir -PathType Container | Should Be $True
        Test-Path (Join-Path $vcapDir "bin") -PathType Container | Should Be $True
        Test-Path (Join-Path $vcapDir "log") -PathType Container | Should Be $True
    }

    It "populates the created directories with the BOSH agent executable(s)" {
	{ Copy-Agent -installDir $installDir -agentZipPath $agentZipPath } | Should Not Throw
        Test-Path (Join-Path $boshDir "bosh-agent.exe") | Should Be $True
        Test-Path (Join-Path $boshDir "service_wrapper.exe") | Should Be $True
        Test-Path (Join-Path $boshDir "service_wrapper.xml") | Should Be $True

        $depsDir = (Join-Path $vcapDir "bin")
        Test-Path (Join-Path $depsDir "job-service-wrapper.exe") | Should Be $True
        Test-Path (Join-Path $depsDir "pipe.exe") | Should Be $True
        Test-Path (Join-Path $depsDir "tar.exe") | Should Be $True
        Test-Path (Join-Path $depsDir "zlib1.dll") | Should Be $True
        Test-Path (Join-Path $depsDir "bosh-blobstore-dav.exe") | Should Be $True
        Test-Path (Join-Path $depsDir "bosh-blobstore-s3.exe") | Should Be $True
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

    Context "when provided a nonexistent directory" {
        It "throws" {
            { Protect-Dir -path "nonexistent-dir" } | Should Throw "Error setting ACL for nonexistent-dir: does not exist"
        }
    }

    It "sets the correct ACLs on the provided directory" {
        { Protect-Dir -path $aclDir } | Should Not Throw

        $acl = (Get-Acl $aclDir)
        $acl.Owner | Should Be "BUILTIN\Administrators"
        $acl.Access | where { $_.IdentityReference -eq "BUILTIN\Users" } | Should BeNullOrEmpty
        $acl.Access | where { $_.IdentityReference -eq "BUILTIN\IIS_IUSRS" } | Should BeNullOrEmpty
        $adminAccess = ($acl.Access | where { $_.IdentityReference -eq "$env:computername\Administrator" })
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

Describe "Write-AgentConfig" {
    BeforeEach {
	    $boshDir=(New-TempDir)
    }

    AfterEach {
	    Remove-Item -Recurse -Force $boshDir
    }

    Context "when IaaS is not provided" {
        It "throws" {
            { Write-AgentConfig -BoshDir $boshDir } | Should Throw "Provide an IaaS for configuration"
        }
    }
    Context "when IaaS is not supported" {
	    It "throws" {
	        { Write-AgentConfig -BoshDir $boshDir -IaaS idontexist } | Should Throw "IaaS idontexist is not supported"
	    }
    }

    Context "when boshDir is not provided" {
	    It "throws" {
	        { Write-AgentConfig -IaaS aws } | Should Throw "Provide a directory to install the BOSH agent config"
	    }
    }
    Context "when provided a nonexistent directory" {
        It "throws" {
            { Write-AgentConfig -BoshDir "nonexistent-dir" -IaaS aws } | Should Throw "Error: nonexistent-dir does not exist"
        }
    }

    Context "when IaaS is 'aws'" {
        It "writes the agent config for aws" {
            { Write-AgentConfig -BoshDir $boshDir -IaaS aws } | Should Not Throw
            $configPath = (Join-Path $boshDir "agent.json")
            Test-Path $configPath | Should Be $True
            ($configPath) | Should Contain ([regex]::Escape('"SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key/"'))
        }
    }

    Context "when IaaS is 'azure'" {
        It "writes the agent config for azure" {
            { Write-AgentConfig -BoshDir $boshDir -IaaS azure } | Should Not Throw
            $configPath = (Join-Path $boshDir "agent.json")
            Test-Path $configPath | Should Be $True
            ($configPath) | Should Contain ([regex]::Escape('"SettingsPath": "C:/AzureData/CustomData.bin"'))
            ($configPath) | Should Contain ([regex]::Escape('"MetaDataPath": "C:/AzureData/CustomData.bin"'))
            ($configPath) | Should Contain ([regex]::Escape('"UseServerName": false'))
        }
    }

    Context "when IaaS is 'gcp'" {
        It "writes the agent config for gcp" {
            { Write-AgentConfig -BoshDir $boshDir -IaaS gcp } | Should Not Throw
            $configPath = (Join-Path $boshDir "agent.json")
            Test-Path $configPath | Should Be $True
            ($configPath) | Should Contain ([regex]::Escape('"Metadata-Flavor": "Google"'))
        }
    }
    Context "when IaaS is 'vsphere'" {
        It "writes the agent config for vsphere" {
            { Write-AgentConfig -BoshDir $boshDir -IaaS vsphere } | Should Not Throw
            $configPath = (Join-Path $boshDir "agent.json")
            Test-Path $configPath | Should Be $True
            ($configPath) | Should Contain ([regex]::Escape('"Type": "CDROM"'))
        }
    }
}

Describe "Set-Path" {
    BeforeEach {
	    $oldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
        $tempDir=(New-TempDir)
    }

    AfterEach {
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $oldPath
        Remove-Item -Recurse -Force $tempDir
    }

    It "sets the system path" {
        { Set-Path -Path $tempDir} | Should Not Throw
        $path = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
        $path | Should Match ([regex]::Escape($tempDir))
    }

    Context "when not provided a path to add" {
        It "throws" {
            { Set-Path } | Should Throw "Error: Provide a directory to add to the path"
        }
    }
}

Describe "Install-Agent" {
    It "calls service_wrapper.exe" {
        Mock -Verifiable -ModuleName BOSH.Agent Start-Process {} -ParameterFilter { $FilePath -eq "C:\bosh\service_wrapper.exe" -and $ArgumentList -eq "install" -and $NoNewWindow -and $Wait }
        Install-AgentService
        Assert-VerifiableMocks
    }
}

Describe "Install-Agent" {
    Context "when IaaS is not provided" {
        It "throws" {
            { Install-Agent -agentZipPath "some-agent-zip-path" } | Should Throw "Provide the IaaS of your VM"
        }
    }
    Context "when agent.zip is not provided" {
        It "throws" {
            { Install-Agent -IaaS "some-Iaas" } | Should Throw "Provide the path of your agent.zip"
        }
    }

    It "calls helper functions with default arguments" {
        Mock -Verifiable -ModuleName BOSH.Agent Copy-Agent {} -ParameterFilter { $InstallDir -eq "C:\" -and $agentZipPath -eq "some-agent-zip-path" }

        Mock -Verifiable -ModuleName BOSH.Agent Protect-Dir {} -ParameterFilter { $path -eq "C:\bosh" }
        Mock -Verifiable -ModuleName BOSH.Agent Protect-Dir {} -ParameterFilter { $path -eq "C:\var" }
        Mock -Verifiable -ModuleName BOSH.Agent Protect-Dir {} -ParameterFilter { $path -eq "C:\Windows\Panther" -and $disableInheritance -eq $false }

        Mock -Verifiable -ModuleName BOSH.Agent Write-AgentConfig {} -ParameterFilter { $IaaS -eq "aws" -and $BoshDir -eq "C:\bosh" }
        Mock -Verifiable -ModuleName BOSH.Agent Set-Path -Path "C:\var\vcap\bosh\bin" {}
        Mock -Verifiable -ModuleName BOSH.Agent Install-AgentService {}
        Install-Agent -IaaS aws -agentZipPath "some-agent-zip-path"
        Assert-VerifiableMocks
    }
}

Remove-Module -Name BOSH.Agent -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
