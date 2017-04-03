Remove-Module -Name BOSH.WindowsUpdates -ErrorAction Ignore
Import-Module ./BOSH.WindowsUpdates.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "List-Updates" {
    It "lists updates" {
       $result = List-Updates
       $result.Length | Should BeGreaterThan 0
       $result[0] | Should BeLike 'KB*'
    }
}

Describe "Disable-AutomaticUpdates" {
    BeforeEach {
        $oldWuauStatus = (Get-Service -Name "wuauserv").Status
        { Set-Service -Name wuauserv -Status "Running" } | Should Not Throw
        $oldWuauStartMode = (Get-WmiObject -Class Win32_Service -Property StartMode -Filter "Name='wuauserv'").StartMode

        $oldAUOptions = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').AUOptions
        $oldEnableFeaturedSoftware = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').EnableFeaturedSoftware
        $oldIncludeRecUpdates = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').IncludeRecommendedUpdates
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 2 -Name 'AUOptions'
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 2 -Name 'EnableFeaturedSoftware'
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value 2 -Name 'IncludeRecommendedUpdates'

        { Disable-AutomaticUpdates } | Should Not Throw
    }

    AfterEach {
        if ($oldAUOptions -eq "") {
            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'AUOptions'
        } else {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value $oldAUOptions -Name 'AUOptions'
        }

        if ($oldEnableFeaturedSoftware -eq "") {
            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'EnableFeaturedSoftware'
        } else {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value $oldEnableFeaturedSoftware -Name 'EnableFeaturedSoftware'
        }

        if ($oldIncludeRecUpdates -eq "") {
            Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'IncludeRecommendedUpdates'
        } else {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Value $oldAUOptions -Name 'IncludeRecommendedUpdates'
        }

        { Set-Service -Name wuauserv -StartupType $oldWuauStartMode } | Should Not Throw
        { Set-Service -Name wuauserv -Status $oldWuauStatus } | Should Not Throw
    }

    It "stops and disables the Windows Updates service" {
        (Get-Service -Name "wuauserv").Status | Should Be "Stopped"
        (Get-WmiObject -Class Win32_Service -Property StartMode -Filter "Name='wuauserv'").StartMode | Should Be "Disabled"
    }

    It "sets registry keys to stop automatically installing updates" {
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').AUOptions | Should Be "1"
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').EnableFeaturedSoftware | Should Be "0"
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update').IncludeRecommendedUpdates | Should Be "0"
    }
}

Remove-Module -Name BOSH.WindowsUpdates -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
