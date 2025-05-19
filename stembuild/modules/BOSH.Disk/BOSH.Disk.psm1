<#
.Synopsis
    Install BOSH Disk Utilities
.Description
    This cmdlet installs the Disk Utilities for BOSH deployed vm
#>

function Compress-Disk {
    Write-Log "Starting to compress disk"
    DefragDisk
    ZeroDisk
    DefragDisk # Just for good measure
    Write-Log "Finished compressing disk"
}

function Optimize-Disk {
    Write-Log "Starting to clean disk"

    Remove-Available-Windows-Features

    # Cleanup WinSxS folder: https://technet.microsoft.com/en-us/library/dn251565.aspx
    # /LogLevel default is 3
    Write-Log "Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /StartComponentCleanup /ResetBase'"
    Dism.exe /online /LogLevel:4 /Cleanup-Image /StartComponentCleanup /ResetBase
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Error: Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /StartComponentCleanup /ResetBase'"
        Throw "Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /StartComponentCleanup /ResetBase' failed"
    }

    Write-Log "Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /SPSuperseded'"
    Dism.exe /online /LogLevel:4 /Cleanup-Image /SPSuperseded
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Error: Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /SPSuperseded'"
        Throw "Running 'Dism.exe /online /LogLevel:4 /Cleanup-Image /SPSuperseded' failed"
    }

    Write-Log "Finished clean disk"
}

function Remove-Available-Windows-Features {
    Write-Log "Starting to remove 'Available' Windows Features"

    Get-WindowsFeature |
            ? { $_.InstallState -eq 'Available' } |
            Uninstall-WindowsFeature -Remove

    Write-Log "Finished removing 'Available' Windows Features"
}

function DefragDisk {
    # First - get the volumes via WMI
    $volumes = gwmi win32_volume

    # Now get the C:\ volume
    $v1 = $volumes | where {$_.name -eq "C:\"}

    # Perform a defrag analysis
    $v1.defraganalysis().defraganalysis

    Write-Log "DefragDisk: Volume: ${v1}"
    $v1.defrag($true)

    Write-Log "DefragDisk: Redo Defrag analysis: ${v1}"
    $v1.defraganalysis().defraganalysis
}

function ZeroDisk {
    $Success = $TRUE
    $FilePath = "C:\zero.tmp"
    $Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
    $ArraySize = 64kb
    $SpaceToLeave = $Volume.Size * 0.005
    $FileSize = $Volume.FreeSpace - $SpacetoLeave
    $ZeroArray = New-Object byte[]($ArraySize)

    Write-Log "Zeroing volume: $Volume"
    $Stream = [io.File]::OpenWrite($FilePath)
    $CurFileSize = 0
    while ($CurFileSize -lt $FileSize) {
        $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
        $CurFileSize +=$ZeroArray.Length
    }
    if ($Stream) {
        $Stream.Close()
    }
    Remove-Item -Path $FilePath -Force
}
