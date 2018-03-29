# Get max partition size of volume
$GiB = [math]::pow(1024, 3)

$MaxPartitionSize = $(Get-PartitionSupportedSize -DriveLetter C).SizeMax
$MaxPartSizeGiB = [math]::ceiling($MaxPartitionSize / $GiB)
Write-Host "Current disk size: ${MaxPartSizeGiB}"
if ($MaxPartSizeGiB -ne 200) {
    Write-Error "Disk size is not set to 200GB: Failing test"
    Exit 1
}


# Get allocated space of drive C
$AllocatedSpace = $(Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").Size
$AllocatedSpaceGiB = [math]::ceiling($AllocatedSpace / $GiB)
Write-Host  "Current partition size: ${AllocatedSpaceGiB}"

$AbsDiff = [math]::abs($MaxPartitionSize - $AllocatedSpace)
$AbsDiffGiB = [math]::floor($AbsDiff / $GiB)
Write-Host "Unused space: ${AbsDiffGiB}"

if ($AbsDiff -gt $GiB) {
    Write-Error "Drive C (${AllocatedSpace} B) does not take up entire disk (${MaxPartitionSize} B)"
    Exit 1
}

Exit 0
