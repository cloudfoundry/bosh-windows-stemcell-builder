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

function Protect-CFCell {
  enable-rdp
  disable-service("WinRM")
  disable-service("W3Svc")
  set-firewall
}

function WindowsFeatureInstall {
  param ([string]$feature)

  Write-Log "Installing $feature"
  If (!(Get-WindowsFeature $feature).Installed) {
    Install-WindowsFeature $feature
    If (!(Get-WindowsFeature $feature).Installed) {
      Throw "Failed to install $feature"
    }
  }
}

function enable-rdp {
  Write-Log "Starting to enable RDP"
  Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
  Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
  Write-Log "Enabled RDP"
}

function disable-service {
  Param([string]$Service)

  Write-Log "Starting to disable $Service"
  Get-Service | Where-Object {$_.Name -eq $Service } | Set-Service -StartupType Disabled
  Write-Log "Disabled $Service"
}

function set-firewall {
  Write-Log "Starting to set firewall rules"
	Set-NetFirewallProfile -all -DefaultInboundAction Block -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True
	check-firewall "public"
	check-firewall "private"
	check-firewall "domain"
  Write-Log "Finished setting firewall rules"
}

function get-firewall {
  param([string] $profile)

  $firewall = (Get-NetFirewallProfile -Name $profile)
  $result = "{0},{1},{2}" -f $profile,$firewall.DefaultInboundAction,$firewall.DefaultOutboundAction
  return $result

}

function check-firewall {
  param([string] $profile)

  $firewall = (get-firewall $profile)
  Write-Log $firewall
  if ($firewall -ne "$profile,Block,Allow") {
    Write-Log $firewall
    Throw "Unable to set $profile Profile"
  }
}

