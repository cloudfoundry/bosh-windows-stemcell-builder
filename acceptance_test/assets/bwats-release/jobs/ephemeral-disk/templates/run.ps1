$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

function Get-Config {
  $configPath = Join-Path $PSScriptRoot "config.json"
  Write-Host "Loading '$configPath'"
  $config = Get-Content $configPath -raw | ConvertFrom-Json
  Write-Host "Loaded '$configPath'"
  return $config
}

function New-RandomFile {
    param (
        [Parameter(Mandatory = $false)]
        [int64] $Size = 2gb,
        [Parameter(Mandatory = $false)]
        [string] $Path = ('c:/var/vcap/data/{1}' -f $HOME, (New-Guid).Guid),
        [Parameter(Mandatory = $false)]
        [int] $BufferSize = 4096
    )
    begin {
        $MyBuffer = [System.Byte[]]::new($BufferSize)
        $Random = [System.Random]::new()
        $FileStream = [System.IO.File]::OpenWrite($Path)
        $TotalSize = $FileStream.Length
        $FileStream.Position = $FileStream.Length
        Write-Verbose -Message ('File current size is: {0}' -f $FileStream.Length)
    }

    process {
        while ($TotalSize -lt $Size) {
            $Random.NextBytes($MyBuffer)
            $FileStream.Write($MyBuffer, 0, $MyBuffer.Length)
            $TotalSize += $BufferSize
            Write-Verbose -Message ('Appended {0} bytes to file {1}' -f $BufferSize, $Path)
        }
    }
    end {
        $FileStream.Close()
        [PSCustomObject]@{
            Path = $Path
        }
    }
}

$config = Get-Config

if ($config.run_test_enabled -eq "true") {
    # Note no trailing slash. Important! Trailing slashes on non-symlink folders will return their own path as the target
    # eg (get-item "C:\var\vcap\data\").target -> c:\var\vcap\data

    $dataTarget = (get-item "C:\var\vcap\data").Target
    if ($dataTarget -eq $null) {
        Write-Error "Data partition should be created: target is $dataTarget"
        Exit 1
    }

    $targetDriveLetter = $dataTarget.substring(0,1)
    $dataPartition = get-partition -driveLetter $targetDriveLetter

    $randFileSize = 2gb

    $ephemeralDiskSpaceBeforeFill = (Get-Volume -Partition $dataPartition).SizeRemaining
    $rootDiskSpaceBeforeFill = (Get-Volume -DriveLetter C).SizeRemaining

    New-RandomFile -Size $randFileSize

    $rootDiskSpaceAfterFill = (Get-Volume -DriveLetter C).SizeRemaining
    $ephemeralDiskSpaceAfterFill = (Get-Volume -Partition $dataPartition).SizeRemaining

    $rootDiskDelta = $rootDiskSpaceBeforeFill - $rootDiskSpaceAfterFill
    $ephemeralDiskDelta = $ephemeralDiskSpaceBeforeFill - $ephemeralDiskSpaceAfterFill

    Write-Host "Delta: $rootDiskDelta"
    Write-Host "Ephemeral Delta: $ephemeralDiskDelta"

    if ($rootDiskDelta -ge $randFileSize) {
      Write-Error "Ephemeral disk was not properly mounted to data path. Delta : $rootDiskDelta"
      Exit 1
    }

    if ($ephemeralDiskDelta -lt $randFileSize -or $ephemeralDiskDelta -gt 2 * $randFileSize) {
      Write-Error "Ephemeral disk was not properly mounted to data path. Ephemeral Delta : $ephemeralDiskDelta"
      Exit 1
    }
} else {
    $dataTarget = (get-item "C:\var\vcap\data").target
    if ($dataTarget -ne $null) {
      Write-Error "Data partition should not be created"
      Exit 1
    }
}

Exit 0