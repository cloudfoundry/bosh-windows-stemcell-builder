Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Import-Module ./BOSH.CFCell.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "Protect-CFCell" {
    It "enables the RDP service and firewall rule" {
       Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
       netstat /p tcp /a | findstr 3389 | Should BeNullOrEmpty
       Protect-CFCell
       netstat /p tcp /a | findstr 3389 | Should Not BeNullOrEmpty
    }
    It "disables the services" {
       Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Automatic
       Get-Service | Where-Object {$_.Name -eq "W3Svc" } | Set-Service -StartupType Automatic
       Protect-CFCell
       (Get-Service | Where-Object {$_.Name -eq "WinRM" } ).StartType| Should be "Disabled"
       (Get-Service | Where-Object {$_.Name -eq "W3Svc" } ).StartType | Should be "Disabled"
    }
    It "sets firewall rules" {
        Set-NetFirewallProfile -all -DefaultInboundAction Allow -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True
        get-firewall "public" | Should be "public,Allow,Allow"
        get-firewall "private" | Should be "private,Allow,Allow"
        get-firewall "domain" | Should be "domain,Allow,Allow"
        Protect-CFCell
        get-firewall "public" | Should be "public,Block,Allow"
        get-firewall "private" | Should be "private,Block,Allow"
        get-firewall "domain" | Should be "domain,Block,Allow"
    }
}

Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
