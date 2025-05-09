<#
.Synopsis
    AbsolutePathChroot
.Description
    This cmdlet is for use in tests to mock filesystem operations, so absolute paths become relative
#>

function AbsolutePathChroot-New-Item {
    param(
        $Path
    )
    $optionalDriveLetterRegex = "(.:)?(.+)"
    $pathWithoutDriveName = $Path -replace $optionalDriveLetterRegex, '$2'

    $safePath=".\"

    New-Item -Path "$safePath$pathWithoutDriveName" @Args
}
