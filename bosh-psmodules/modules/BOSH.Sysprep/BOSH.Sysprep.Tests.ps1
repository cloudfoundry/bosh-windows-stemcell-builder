Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Import-Module ./BOSH.Sysprep.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Enable-LocalSecurityPolicy" {
    BeforeEach {
        $PolicyDestination=(New-TempDir)
    }

    AfterEach {
        Remove-Item -Recurse -Force $PolicyDestination
    }

    Context "when LgpoExe is not provided" {
        It "throws" {
            { Enable-LocalSecurityPolicy } | Should Throw "Provide a path for lgpo.exe"
        }
    }

    It "places the policy files in the destination and runs lgpo.exe" {
        $lgpoExe = "cmd.exe /c 'echo hello'"
        { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Not Throw
        (Test-Path (Join-Path $PolicyDestination "policy-baseline")) | Should Be $True
        (Join-Path $PolicyDestination "lgpo.log") | Should Contain "hello"
    }

    Context "when lgpo.exe fails" {
        It "throws" {
            $lgpoExe = "cmd.exe /c 'exit 1'"
            { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Throw "lgpo.exe exited with 1"
        }
    }
}

Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
