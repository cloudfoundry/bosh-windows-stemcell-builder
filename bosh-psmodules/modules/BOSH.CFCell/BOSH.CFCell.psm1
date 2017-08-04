<#
.Synopsis
    Install CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell
#>
function Install-CFFeatures {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Installing CloudFoundry Cell Windows Features"
  $ErrorActionPreference = "Stop";
  trap { $host.SetShouldExit(1) }

  $windowsVersion = (Get-WmiObject -class Win32_OperatingSystem).Caption
  if ($windowsVersion -Match "2012") {
    WindowsFeatureInstall("Web-Webserver")
    WindowsFeatureInstall("Web-WebSockets")
    WindowsFeatureInstall("AS-Web-Support")
    WindowsFeatureInstall("AS-NET-Framework")
    WindowsFeatureInstall("Web-WHC")
    WindowsFeatureInstall("Web-ASP")
  } elseif ($windowsVersion -Match "2016") {
    WindowsFeatureInstall("FS-Resource-Manager")
  
    if ((Get-Command "docker.exe" -ErrorAction SilentlyContinue) -eq $null) {
      Write-Host "Installing Docker"

      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      $version = (Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/docker/docker/master/VERSION).Content.Trim()
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest "https://master.dockerproject.org/windows/x86_64/docker-$($version).zip" -OutFile "$env:TEMP\docker.zip" -UseBasicParsing
      Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath $env:ProgramFiles
      $env:path += ";$env:ProgramFiles\Docker"
      $existingMachinePath = [Environment]::GetEnvironmentVariable("Path",[System.EnvironmentVariableTarget]::Machine)
      [Environment]::SetEnvironmentVariable("Path", $existingMachinePath + ";$env:ProgramFiles\Docker", [EnvironmentVariableTarget]::Machine)
      dockerd --register-service
      Start-Service Docker
      Write-Host "Installed Docker"
    }

    docker.exe pull cloudfoundry/windows2016fs
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Non-zero exit code ($LASTEXITCODE): docker.exe pull cloudfoundry/windows2016fs"
    }
    Write-Host "installed cloudfoundry/windows2016fs image!"
  }

  Write-Log "Installed CloudFoundry Cell Windows Features"
}

function Install-ContainersFeature {
  $windowsVersion = (Get-WmiObject -class Win32_OperatingSystem).Caption
  if ($windowsVersion -Match "2016") {
    Write-Log "Setting WinRM startup type to automatic"
    Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Automatic
    WindowsFeatureInstall("Containers")
    shutdown /r /c "packer restart" /t 5
    net stop winrm
  }
}

function Protect-CFCell {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"
  enable-rdp
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"
  disable-service("WinRM")
  disable-service("W3Svc")
  set-firewall
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"
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

