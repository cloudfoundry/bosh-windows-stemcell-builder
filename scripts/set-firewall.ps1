$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Set-NetFirewallProfile -all -DefaultInboundAction Block -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True

function get-firewall {
  param([string] $profile)

  $firewall = (Get-NetFirewallProfile -Name $profile)
  $result = "{0},{1},{2}" -f $profile,$firewall.DefaultInboundAction,$firewall.DefaultOutboundAction
  return $result

}

function check-firewall {
  param([string] $profile)

  $firewall = (get-firewall $profile)
  Write-Host $firewall
  if ($firewall -ne "$profile,Block,Allow") {
    Write-Host $firewall
    Write-Error "Unable to set $profile Profile"
  }

}

check-firewall "public"
check-firewall "private"
check-firewall "domain"

# Permit 3389 for RDP
$rdp_port="3389"

if (-Not (Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "RdpPort" })) {
  New-NetFirewallRule -DisplayName "RdpPort" -Action Allow -Direction Inbound -Enabled True -LocalPort $rdp_port -Protocol TCP
  if (-Not (Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "RdpPort" })) {
    Write-Error "Unable to add RdpPort firewall rule"
  }
}

Exit 0
