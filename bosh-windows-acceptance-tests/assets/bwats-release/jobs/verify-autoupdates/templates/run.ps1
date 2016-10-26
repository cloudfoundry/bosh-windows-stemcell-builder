$AutoUpdateRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"

$ExpectedAUOptions = 1
$ExpectedEnableFeaturedSoftware = 0
$ExpectedIncludeRecommendedUpdates = 0

$ReturnCode = 0

$AutoUpdateProperties = Get-ItemProperty -Path $AutoUpdateRegistryPath

if ($AutoUpdateProperties.AUOptions -and
    $AutoUpdateProperties.AUOptions -ne $ExpectedAUOptions) {
    Write-Error "Error: Expected AUOptions to be '${ExpectedAUOptions}', got '${AutoUpdateProperties.AUOptions}'"
    $ReturnCode = 1
}

if ($AutoUpdateProperties.EnableFeaturedSoftware -and
    $AutoUpdateProperties.EnableFeaturedSoftware -ne $ExpectedEnableFeaturedSoftware) {
    Write-Error "Error: Expected EnableFeaturedSoftware to be '${ExpectedEnableFeaturedSoftware}'," + `
                " got '${AutoUpdateProperties.EnableFeaturedSoftware}'"
    $ReturnCode = 1
}

if ($AutoUpdateProperties.IncludeRecommendedUpdates -and
    $AutoUpdateProperties.IncludeRecommendedUpdates -ne $ExpectedIncludeRecommendedUpdates) {
    Write-Error "Error: Expected IncludeRecommendedUpdates to be '${ExpectedIncludeRecommendedUpdates}'," + `
                " got '${AutoUpdateProperties.IncludeRecommendedUpdates}'"
    $ReturnCode = 1
}

Exit $ReturnCode
