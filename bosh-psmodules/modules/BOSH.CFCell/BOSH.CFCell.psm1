<#
.Synopsis
    Install Windows 2012 CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell on Windows 2012R2
#>
function Install-CFFeatures2012 {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Installing CloudFoundry Cell Windows 2012 Features"
  $ErrorActionPreference = "Stop";
  trap { $host.SetShouldExit(1) }

  WindowsFeatureInstall("Web-Webserver")
  WindowsFeatureInstall("Web-WebSockets")
  WindowsFeatureInstall("AS-Web-Support")
  WindowsFeatureInstall("AS-NET-Framework")
  WindowsFeatureInstall("Web-WHC")
  WindowsFeatureInstall("Web-ASP")

  Write-Log "Installed CloudFoundry Cell Windows 2012 Features"
}

<#
.Synopsis
    Install Windows 2016 CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell on Windows 2016
#>
function Install-CFFeatures2016 {
  param ([switch]$ReduceMTU)

  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Installing CloudFoundry Cell Windows 2016 Features"
  $ErrorActionPreference = "Stop";
  trap { $host.SetShouldExit(1) }

  WindowsFeatureInstall("FS-Resource-Manager")

  if ((Get-Command "docker.exe" -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host "Installing Docker"

    $ifaces = (Get-NetIPInterface -AddressFamily IPv4).InterfaceAlias

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

    if ($ReduceMTU) {
      # Get a list of network interfaces created by installing Docker.
      $newIfaces=Wait-ForNewIfaces $ifaces

      foreach ($name in $newIfaces) {
        Write-Host "Setting the MTU of network interface to 1460: $name"

        netsh.exe interface ipv4 set subinterface "$name" mtu=1460 store=persistent
        if ($LASTEXITCODE -ne 0) {
          Write-Error "Error setting MTU for network interface: '$name': exit code: $LASTEXITCODE"
        }
      }
    }
  }


  docker.exe pull cloudfoundry/windows2016fs
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Non-zero exit code ($LASTEXITCODE): docker.exe pull cloudfoundry/windows2016fs"
  }
  Write-Host "installed cloudfoundry/windows2016fs image!"

  Write-Log "Installed CloudFoundry Cell Windows 2016 Features"
}

function Wait-ForNewIfaces() {
    param([string]$ifaces)
    $max = 20
    $try = 0

    while($try -le $max) {
        # Get a list of network interfaces created by installing Docker.
        $newIfaces=(Get-NetIPInterface -AddressFamily IPv4 | where {
        -Not ($_.InterfaceAlias -in $ifaces) -and $_.NlMtu -eq 1500
        }).InterfaceAlias

        if($newIfaces.Count -gt 0) {
            Write-Host "Docker added interfaces: $newIfaces"
            return $newIfaces
        }
        Start-Sleep -s 5
        $try++
    }

    Write-Error "Time-out waiting for docker to add Network Interface on GCP"
    Throw "Should not get here"
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

  Write-Log "Disabling NetBIOS over TCP"
  Disable-NetBIOS
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

<#
.Synopsis
    Disables NetBIOS over TCP
.Description
    This cmdlet disables NetBIOS over TCP by configuring the network interfaces
    and by disabling all associated firewall rules.  Additionally, the ports
    used by NetBIOS over TCP are explicitly blocked.
#>
function Disable-NetBIOS {

    # Disable NetBIOS over TCP at the network interface level

    $NoInstances=$false
    WMIC.exe NICCONFIG WHERE '(TcpipNetbiosOptions=0 OR TcpipNetbiosOptions=1)' GET Caption,Index,TcpipNetbiosOptions 2>&1 | foreach {
        $NoInstances = $NoInstances -or $_ -like '*No Instance(s) Available*'
    }
    if ($NoInstances) {
        Write-Log "NetBIOS over TCP is not enabled on any network interfaces"
    } else {
        # List Interfaces that will be changed
        Write-Log "NetBIOS over TCP will be disabled on the following network interfaces:"
        WMIC.exe NICCONFIG WHERE '(TcpipNetbiosOptions=0 OR TcpipNetbiosOptions=1)' GET Caption,Index,TcpipNetbiosOptions

        # Disable NetBIOS over TCP
        WMIC.exe NICCONFIG WHERE '(TcpipNetbiosOptions=0 OR TcpipNetbiosOptions=1)' CALL SetTcpipNetbios 2
    }

    # Disable NetBIOS firewall rules

    $BuiltinNetBIOSRules=@(
        "NETDIS-NB_Name-In-UDP",
        "NETDIS-NB_Name-Out-UDP",
        "NETDIS-NB_Datagram-In-UDP",
        "NETDIS-NB_Datagram-Out-UDP",
        "FPS-NB_Session-In-TCP",
        "FPS-NB_Session-Out-TCP",
        "FPS-NB_Name-In-UDP",
        "FPS-NB_Name-Out-UDP",
        "FPS-NB_Datagram-In-UDP",
        "FPS-NB_Datagram-Out-UDP"
    )
    foreach ($name in $BuiltinNetBIOSRules) {
        Write-Log "Disabling firewall rule: $name"
        Disable-NetFirewallRule -Name $name
    }

    # Explicitly block NetBIOS Over TCP/IP:
    #
    # This blocks access to the below ports:
    #
    #   - UDP port 137 (name services)
    #   - UDP port 138 (datagram services)
    #   - TCP port 139 (session services)
    #
    # source: https://technet.microsoft.com/en-us/library/cc940063.aspx

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Name-Disable-In-UDP")) {
        Write-Log "Creating firewall rule: NB_Name-Disable-In-UDP"
        New-NetFirewallRule `
            -Name "NB_Name-Disable-In-UDP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-In)" `
            -Direction Inbound `
            -Action Block `
            -Protocol UDP `
            -LocalPort 137
    }

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Name-Disable-Out-UDP")) {
        Write-Log "Creating firewall rule: NB_Name-Disable-Out-UDP"
        New-NetFirewallRule `
            -Name "NB_Name-Disable-Out-UDP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-Out)" `
            -Direction Outbound `
            -Action Block `
            -Protocol UDP `
            -RemotePort 137
    }

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Datagram-Disable-In-UDP")) {
        Write-Log "Creating firewall rule: NB_Datagram-Disable-In-UDP"
        New-NetFirewallRule `
            -Name "NB_Datagram-Disable-In-UDP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-In)" `
            -Direction Inbound `
            -Action Block `
            -Protocol UDP `
            -LocalPort 138
    }

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Datagram-Disable-Out-UDP")) {
        Write-Log "Creating firewall rule: NB_Datagram-Disable-Out-UDP"
        New-NetFirewallRule `
            -Name "NB_Datagram-Disable-Out-UDP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-Out)" `
            -Direction Outbound `
            -Action Block `
            -Protocol UDP `
            -RemotePort 138
    }

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Session-Disable-In-TCP")) {
        Write-Log "Creating firewall rule: NB_Session-Disable-In-TCP"
        New-NetFirewallRule `
            -Name "NB_Session-Disable-In-TCP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-In)" `
            -Direction Inbound `
            -Action Block `
            -Protocol TCP `
            -LocalPort 139
    }

    if (-Not ((Get-NetFirewallRule).Name -contains "NB_Session-Disable-Out-TCP")) {
        Write-Log "Creating firewall rule: NB_Session-Disable-Out-TCP"
        New-NetFirewallRule `
            -Name "NB_Session-Disable-Out-TCP" `
            -DisplayName "Disable File and Printer Sharing (NB-Session-Out)" `
            -Direction Outbound `
            -Action Block `
            -Protocol TCP `
            -RemotePort 139
    }

    $ExplicitBlockNetBIOSRules=@(
        "NB_Name-Disable-In-UDP",
        "NB_Name-Disable-Out-UDP",
        "NB_Datagram-Disable-In-UDP",
        "NB_Datagram-Disable-Out-UDP",
        "NB_Session-Disable-In-TCP",
        "NB_Session-Disable-Out-TCP"
    )
    foreach ($name in $ExplicitBlockNetBIOSRules) {
        Write-Log "Enabling firewall rule: $name"
        Enable-NetFirewallRule -Name $name
    }

    Write-Log "Disable-NetBIOS: Complete"
}
