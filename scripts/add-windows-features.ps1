$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Function WindowsFeatureInstall([string]$feature)
{
  Write-Host "Installing $feature"
  If (!(Get-WindowsFeature $feature).Installed) {
    Install-WindowsFeature $feature
    If (!(Get-WindowsFeature $feature).Installed) {
      Write-Error "Failed to install $feature"
    }
  }
}

WindowsFeatureInstall("Web-Webserver")
WindowsFeatureInstall("Web-WebSockets")
WindowsFeatureInstall("AS-NET-Framework")
WindowsFeatureInstall("Web-WHC")
WindowsFeatureInstall("Web-ASP")

Exit 0
