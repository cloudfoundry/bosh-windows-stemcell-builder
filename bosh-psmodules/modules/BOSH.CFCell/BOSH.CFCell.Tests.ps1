Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Import-Module ./BOSH.CFCell.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "Protect-CFCell" {
    BeforeEach {
        $oldWinRMStatus = (Get-Service winrm).Status
        $oldWinRMStartMode = ( Get-Service winrm ).StartType

        { Set-Service -Name "winrm" -StartupType "Manual" } | Should Not Throw

        Start-Service winrm
    }

    AfterEach {
        if ($oldWinRMStatus -eq "Stopped") {
            { Stop-Service winrm } | Should Not Throw
        } else {
            { Set-Service -Name "winrm" -Status $oldWinRMStatus } | Should Not Throw
        }
        { Set-Service -Name "winrm" -StartupType $oldWinRMStartMode } | Should Not Throw
    }

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
       $w3svcStartType = (Get-Service | Where-Object {$_.Name -eq "W3Svc" } ).StartType
       "Disabled", $null -contains $w3svcStartType | Should Be $true
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

Describe "Disable-1803DockerServices" {

    It "disables features installed in 1803 Azure images with containers" {
        Get-Service | Where-Object {$_.Name -eq "Docker" } | Set-Service -StartupType Automatic
        Get-Service | Where-Object {$_.Name -eq "HgClientService" } | Set-Service -StartupType Automatic
        Get-Service | Where-Object {$_.Name -eq "vmms" } | Set-Service -StartupType Automatic
        Disable-1803DockerServices
        (Get-Service | Where-Object {$_.Name -eq "Docker" } ).StartType| Should be "Disabled"
        (Get-Service | Where-Object {$_.Name -eq "HgClientService" } ).StartType| Should be "Disabled"
        (Get-Service | Where-Object {$_.Name -eq "vmms" } ).StartType| Should be "Disabled"
    }
}

Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
