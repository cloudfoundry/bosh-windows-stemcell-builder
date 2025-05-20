BeforeAll {
    Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
    Import-Module ./BOSH.CFCell.psm1

    Remove-Module -Name BOSH.Utils -ErrorAction Ignore
    Import-Module ../BOSH.Utils/BOSH.Utils.psm1
}

Describe "Protect-CFCell" {
    BeforeEach {
        $oldWinRMStatus = (Get-Service winrm).Status
        $oldWinRMStartMode = ( Get-Service winrm ).StartType

        { Set-Service -Name "winrm" -StartupType "Manual" } | Should -Not -Throw

        Start-Service winrm
    }

    AfterEach {
        if ($oldWinRMStatus -eq "Stopped") {
            { Stop-Service winrm } | Should -Not -Throw
        } else {
            { Set-Service -Name "winrm" -Status $oldWinRMStatus } | Should -Not -Throw
        }
        { Set-Service -Name "winrm" -StartupType $oldWinRMStartMode } | Should -Not -Throw
    }

    It "disables the RDP service and firewall rule" {
       Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
       Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
       Get-Service "Termservice" | Set-Service -StartupType "Automatic"
       netstat /p tcp /a | findstr ":3389 " | Should -Not -BeNullOrEmpty

       Protect-CFCell

       Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" | select -exp fDenyTSConnections | Should -Be 1
       netstat /p tcp /a | findstr ":3389 " | Should -BeNullOrEmpty
       Get-NetFirewallRule -DisplayName "Remote Desktop*" | ForEach { $_.enabled | Should -Be "False" }
       Get-Service "Termservice" | Select -exp starttype | Should -Be "Disabled"
    }

    It "disables the services" {
       Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Automatic
       Get-Service | Where-Object {$_.Name -eq "W3Svc" } | Set-Service -StartupType Automatic
       Protect-CFCell
       (Get-Service | Where-Object {$_.Name -eq "WinRM" } ).StartType| Should -Be "Disabled"
       $w3svcStartType = (Get-Service | Where-Object {$_.Name -eq "W3Svc" } ).StartType
       "Disabled", $null -contains $w3svcStartType | Should -Be $true
    }

    It "sets firewall rules" {
        Set-NetFirewallProfile -all -DefaultInboundAction Allow -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True
        get-firewall "public" | Should -Be "public,Allow,Allow"
        get-firewall "private" | Should -Be "private,Allow,Allow"
        get-firewall "domain" | Should -Be "domain,Allow,Allow"
        Protect-CFCell
        get-firewall "public" | Should -Be "public,Block,Allow"
        get-firewall "private" | Should -Be "private,Block,Allow"
        get-firewall "domain" | Should -Be "domain,Block,Allow"
    }
}

Describe "Install-CFFeatures" {
    It "restarts computer on Microsoft server 2016 and later" {

        Mock -ModuleName BOSH.CFCell Install-CFFeatures2012 { }
        Mock -ModuleName BOSH.CFCell Install-CFFeatures2016 { }
        Mock -ModuleName BOSH.CFCell Write-Error { }
        Mock -ModuleName BOSH.CFCell Get-OSVersionString { "10.0.1803" }

        { Install-CFFeatures } | Should -Not -Throw

        Assert-MockCalled Install-CFFeatures2016 -Times 1 -Scope It -ModuleName BOSH.CFCell -ParameterFilter { $ForceReboot }
        Assert-MockCalled Install-CFFeatures2012 -Times 0 -Scope It -ModuleName BOSH.CFCell
    }
}

Describe "Install-CFFeatures2016" {
    BeforeEach {
        Mock -ModuleName BOSH.CFCell Write-Log { }
        Mock -ModuleName BOSH.CFCell Get-WinRMConfig { "Some config" }
        Mock -ModuleName BOSH.CFCell WindowsFeatureInstall { }
        Mock Uninstall-WindowsFeature { }
        Mock -ModuleName BOSH.CFCell Uninstall-WindowsFeature { }
        Mock -ModuleName BOSH.CFCell Set-Service { }
        # Mock Set-Service { }
        Mock -ModuleName BOSH.CFCell Restart-Computer { }
        Mock -ModuleName BOSH.CFCell Get-OSVersionString { "10.0.1803" }
    }

    It "triggers a machine restart when the -ForceReboot flag is set" {
        { Install-CFFeatures2016 -ForceReboot } | Should -Not -Throw

        Assert-MockCalled Restart-Computer -Times 1 -Scope It -ModuleName BOSH.CFCell
    }

    It "doesn't trigger a machine restart if -ForceReboot flag not set" {
        { Install-CFFeatures2016 } | Should -Not -Throw

        Assert-MockCalled Restart-Computer -Times 0 -Scope It -ModuleName BOSH.CFCell
    }

    It "logs Installing CloudFoundry Cell Windows Features" {
        { Install-CFFeatures2016 } | Should -Not -Throw

        Assert-MockCalled Write-Log -Times 1 -Scope It -ModuleName BOSH.CFCell -ParameterFilter { $Message -eq "Installing CloudFoundry Cell Windows Features" }
    }

    It "logs Installed CloudFoundry Cell Windows Features after installation" {
        { Install-CFFeatures2016 } | Should -Not -Throw

        Assert-MockCalled Write-Log -Times 1 -Scope It -ModuleName BOSH.CFCell -ParameterFilter { $Message -eq "Installed CloudFoundry Cell Windows Features" }
    }
}

Describe "Remove-DockerPackage" {
    It "Is impossible to test this" {
        # Pest has issues mocking functions that use validateSet See: https://github.com/pester/Pester/issues/734
#        Mock -ModuleName BOSH.CFCell Uninstall-Package { }
#        Mock -ModuleName BOSH.CFCell Write-Log { }
#        Mock -ModuleName BOSH.CFCell Uninstall-Module { } -ParameterFilter { $Name -eq "DockerMsftProvider" -and $ErrorAction -eq "Ignore" }
#        Mock -ModuleName BOSH.CFCell Get-HNSNetwork { "test-network" }
#        Mock -ModuleName BOSH.CFCell Remove-HNSNetwork { }
#        Mock -ModuleName BOSH.CFCell remove-DockerProgramData { }
#
#        { Remove-DockerPackage } | Should -Not -Throw
#
#        Assert-MockCalled Uninstall-Package -Times 1
#        Assert-MockCalled Uninstall-Module -Times 1 -Scope It -ParameterFilter { $Name -eq "DockerMsftProvider" -and $ErrorAction -eq "Ignore" } -ModuleName BOSH.CFCell
#        Assert-MockCalled Get-HNSNetwork -Times 1 -Scope It -ModuleName BOSH.CFCell
#        Assert-MockCalled Remove-HNSNetwork -Times 1 -Scope It -ParameterFilter { $ArgumentList -eq "test-network" } -ModuleName BOSH.CFCell
#        Assert-MockCalled remove-DockerProgramData-Times 1 -Scope It -ModuleName BOSH.CFCell
    }
}

