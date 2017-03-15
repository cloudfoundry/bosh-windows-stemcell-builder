<#
.Synopsis
    Install CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell
#>


function Install-CFFeatures {
    Write-Log "Installing CloudFoundry Cell Windows Features"
    $ErrorActionPreference = "Stop";
    trap { $host.SetShouldExit(1) }

    WindowsFeatureInstall("Web-Webserver")
    WindowsFeatureInstall("Web-WebSockets")
    WindowsFeatureInstall("AS-Web-Support")
    WindowsFeatureInstall("AS-NET-Framework")
    WindowsFeatureInstall("Web-WHC")
    WindowsFeatureInstall("Web-ASP")

    Write-Log "Installed CloudFoundry Cell Windows Features"
}

function WindowsFeatureInstall([string]$feature)
{
  Write-Log "Installing $feature"
  If (!(Get-WindowsFeature $feature).Installed) {
    Install-WindowsFeature $feature
    If (!(Get-WindowsFeature $feature).Installed) {
      Write-Error "Failed to install $feature"
    }
  }
}
