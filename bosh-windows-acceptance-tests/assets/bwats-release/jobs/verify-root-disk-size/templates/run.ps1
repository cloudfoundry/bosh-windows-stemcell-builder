# Get max partition size of volume
$MaxPartitionSize = $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Get allocated space of drive C
$AllocatedSpace = $(Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").Size

$AbsDiff = [math]::abs($MaxPartitionSize - $AllocatedSpace)
$GiB = [math]::pow(1024, 3)

if ($AbsDiff -gt $GiB) {
    Write-Error "Drive C (${AllocatedSpace} B) does not take up entire disk (${MaxPartitionSize} B)"
    Exit 1
}

Exit 0
