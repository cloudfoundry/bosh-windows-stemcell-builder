#!/usr/bin/env powershell

Write-Host "Trusting PSGallery Repository."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Host "Installing AWS SDK for PowerShell in" $env:PSModuleLocation
Install-Package -Name AWSPowerShell.NetCore `
    -Source https://www.powershellgallery.com/api/v2/ `
    -ProviderName NuGet `
    -ExcludeVersion `
    -Destination $env:PSModuleLocation `
    -Force