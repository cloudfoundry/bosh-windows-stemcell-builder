Function WindowsFeatureInstall([string]$feature)
{
  Write-Host "Installing $feature"
  If (!(Get-WindowsFeature $feature).Installed) {
    Install-WindowsFeature $feature
    If (!(Get-WindowsFeature $feature).Installed) {
      Write-Error "Failed to install $feature"
      Exit 1
    }
  }
}
try {
  WindowsFeatureInstall("Web-Webserver")
  WindowsFeatureInstall("Web-WebSockets")
  WindowsFeatureInstall("AS-Web-Support")
  WindowsFeatureInstall("AS-NET-Framework")
  WindowsFeatureInstall("Web-WHC")
  WindowsFeatureInstall("Web-ASP")
} catch {
  Write-Error "Exception (add-windows-features): add-windows-features.ps1"
  Write-Error $_.Exception.Message
  Exit 1
}

Exit 0
