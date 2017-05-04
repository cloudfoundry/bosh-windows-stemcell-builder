$ReturnCode = 0

if ((Get-Service wuauserv).Status -ne "Stopped") {
    Write-Error "Error: expected wuauserv service to be Stopped"
    $ReturnCode = 1
}

$StartType = (Get-Service wuauserv).StartType
if ($StartType -ne "Disabled") {
    # On some IaaS's (AWS) updates are disabled, but the service is not running.
    Write-Host "Warning: wuauserv service StartType is not disabled: ${StartType}"
}

$AutoUpdateRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"

$ExpectedAUOptions = 1
$ExpectedEnableFeaturedSoftware = 0
$ExpectedIncludeRecommendedUpdates = 0

$AutoUpdateProperties = Get-ItemProperty -Path $AutoUpdateRegistryPath

if ($AutoUpdateProperties.AUOptions -and
    $AutoUpdateProperties.AUOptions -ne $ExpectedAUOptions) {
    Write-Error ("Error: Expected AUOptions to be '{0}', got '{1}'" -f `
        $ExpectedAUOptions, ($AutoUpdateProperties.AUOptions))
    $ReturnCode = 1
}

# If the AUOptions key is not present (for example GCP) check CachedAUOptions.
if ($AutoUpdateProperties.AUOptions -eq $null) {
    if ($AutoUpdateProperties.CachedAUOptions -ne $null -and
        $AutoUpdateProperties.CachedAUOptions -ne $ExpectedAUOptions) {
        Write-Error ("Error: Expected CachedAUOptions to be '{0}', got '{1}'" -f `
            $ExpectedAUOptions, ($AutoUpdateProperties.CachedAUOptions))
        $ReturnCode = 1
    }
}

if ($AutoUpdateProperties.EnableFeaturedSoftware -and
    $AutoUpdateProperties.EnableFeaturedSoftware -ne $ExpectedEnableFeaturedSoftware) {
    Write-Error ("Error: Expected EnableFeaturedSoftware to be '{0}' got '{1}'" -f `
        $ExpectedEnableFeaturedSoftware, ($AutoUpdateProperties.EnableFeaturedSoftware))
    $ReturnCode = 1
}

if ($AutoUpdateProperties.IncludeRecommendedUpdates -and
    $AutoUpdateProperties.IncludeRecommendedUpdates -ne $ExpectedIncludeRecommendedUpdates) {
    Write-Error ("Error: Expected IncludeRecommendedUpdates to be '{0}', got '{1}'" -f `
        $ExpectedIncludeRecommendedUpdates, ($AutoUpdateProperties.IncludeRecommendedUpdates))
    $ReturnCode = 1
}

Exit $ReturnCode
