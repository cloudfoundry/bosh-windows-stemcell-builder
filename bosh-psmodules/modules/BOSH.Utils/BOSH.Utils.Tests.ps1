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

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
