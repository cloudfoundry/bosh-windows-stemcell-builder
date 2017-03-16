<#
.Synopsis
    Install BOSH Disk Utilities
.Description
    This cmdlet installs the Disk Utilities for BOSH deployed vm
#>



function Compress-Disk {
    $ErrorActionPreference = "Stop";
    trap { $host.SetShouldExit(1) }

    Write-Log "Starting to compress disk"
    DefragDisk
    ZeroDisk
    DefragDisk # Just for good measure
    Write-Log "Finished compressing disk"
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
    $SpaceToLeave = $Volume.Size * 0.05
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
