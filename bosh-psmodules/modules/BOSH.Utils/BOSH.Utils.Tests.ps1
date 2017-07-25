Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ./BOSH.Utils.psm1

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

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
