Remove-Module -Name BOSH.Disk -ErrorAction Ignore
Import-Module ./BOSH.Disk.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Clear-Disk" {
    It "Removes un-neccessary files from system" {
        $helloTxt = "C:\\windows\\temp\\hello.txt"
        echo "hello" >> $helloTxt
        $tempDir = (New-TempDir)
        Write-Log $tempDir
        Clear-Disk
        Test-Path $tempDir | Should be $False
        Test-Path $helloTxt | Should be $False
    }
}

Remove-Module -Name BOSH.Disk -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
