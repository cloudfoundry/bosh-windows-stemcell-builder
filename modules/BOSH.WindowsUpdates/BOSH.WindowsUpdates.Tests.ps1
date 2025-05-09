Remove-Module -Name BOSH.WindowsUpdates -ErrorAction Ignore
Import-Module ./BOSH.WindowsUpdates.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "Disable-AutomaticUpdates" {

    BeforeEach {
        $oldWuauStatus = (Get-Service wuauserv).Status
        $oldWuauStartMode = ( Get-Service wuauserv ).StartType

        { Set-Service -Name wuauserv -StartupType "Manual" } | Should Not Throw
        { Set-Service -Name wuauserv -Status "Running" } | Should Not Throw


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
        if ($oldWuauStatus -eq "Stopped") {
            Stop-Service wuauserv
        } else {
            { Set-Service -Name wuauserv -Status $oldWuauStatus } | Should Not Throw
        }
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

Describe "Enable-SecurityPatches" {
    It "enables CVE-2015-6161" {
        $handlerHardeningPath32Exists = $false
        $oldIExplore32 = ""
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING") {
            $handlerHardeningPathExists32 = $true
            $oldIExplore32 = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING").'iexplore.exe'
        }

        $handlerHardeningPath64Exists = $false
        $oldIExplore64 = ""
        if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING") {
            $handlerHardeningPath64Exists = $true
            $oldIExplore64 = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING").'iexplore.exe'
        }

        { Enable-CVE-2015-6161 } | Should Not Throw

        (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING").'iexplore.exe' | Should Be "1"
        (Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING").'iexplore.exe' | Should Be "1"

        if ($handlerHardeningPath32Exists) {
            if ($oldIExplore32 -eq "")
            {
                Remove-Item-Property -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING" -Name "iexplore.exe"
            } else {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING" -Value $oldIExplore32 -Name "iexplore.exe"
            }
        } else {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING"
        }

        if ($handlerHardeningPath32Exists) {
            if ($oldIExplore64 -eq "")
            {
                Remove-Item-Property -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING" -Name "iexplore.exe"
            } else {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING" -Value $oldIExplore64 -Name "iexplore.exe"
            }
        } else {
            Remove-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ALLOW_USER32_EXCEPTION_HANDLER_HARDENING"
        }
    }

    It "enables CVE-2017-8529" {
        $disclosureFixPathExists32 = $false
        $oldIExplore32 = ""
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX") {
            $disclosureFixPathExists32 = $true
            $oldIExplore32 = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX").'iexplore.exe'
        }

        $disclosureFixPathExists64 = $false
        $oldIExplore64 = ""
        if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX") {
            $disclosureFixPathExists64 = $true
            $oldIExplore64 = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX").'iexplore.exe'
        }

        { Enable-CVE-2017-8529 } | Should Not Throw

        (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX").'iexplore.exe' | Should Be "1"
        (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX").'iexplore.exe' | Should Be "1"

        if ($disclosureFixPathExists32) {
            if ($oldIExplore32 -eq "")
            {
                Remove-Item-Property -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Name "iexplore.exe"
            } else {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Value $oldIExplore32 -Name "iexplore.exe"
            }
        } else {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX"
        }

        if ($disclosureFixPathExists64) {
            if ($oldIExplore64 -eq "")
            {
                Remove-Item-Property -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Name "iexplore.exe"
            } else {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX" -Value $oldIExplore64 -Name "iexplore.exe"
            }
        } else {
            Remove-Item "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_ENABLE_PRINT_INFO_DISCLOSURE_FIX"
        }
    }

    It "enables CredSSP" {
        $credSSPPathExists = $false
        $credSSPParamPathExists = $false
        $oldEcryptOracle = ""
        if ( Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP" )
        {
            $credSSPPathExists = $true
            if ( Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters") {
                $credSSPParamPathExists = $true
                $oldEcryptOracle = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters").AllowEncryptionOracle
            }
        }

        { Enable-CredSSP } | Should Not Throw

        (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters").AllowEncryptionOracle | Should Be "1"

        if ($credSSPPathExists) {
            if ( $credSSPParamPathExists ) {
                if ($oldEcryptOracle -eq "")
                {
                    Remove-Item-Property -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters" -Name "AllowEncryptionOracle"
                } else {
                    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters" -Value $oldEcryptOracle -Name "AllowEncryptionOracle"
                }
            } else {
                Remove-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters"
            }
        } else {
            Remove-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP" -Recurse

        }
    }
}

Describe "Upgrade-PSVersion" {
    It "Only installs if powershell 5.1 or above is not installed" {
        Mock Test-PSVersion { $true } -ModuleName BOSH.WindowsUpdates
        Mock Invoke-WebRequest { } -ModuleName BOSH.WindowsUpdates
        Mock Start-Process { } -ModuleName BOSH.WindowsUpdates

        { Upgrade-PSVersion } | Should Not Throw

        Assert-MockCalled Test-PSVersion -Times 1 -Scope It -ModuleName BOSH.WindowsUpdates
        Assert-MockCalled Invoke-WebRequest -Times 0 -Scope It -ModuleName BOSH.WindowsUpdates
        Assert-MockCalled Start-Process -Times 0 -Scope It -ModuleName BOSH.WindowsUpdates
    }

    It "Only installs if powershell 5.1 or above is not installed" {
        Mock Test-PSVersion { $false } -ModuleName BOSH.WindowsUpdates
        Mock Invoke-WebRequest { } -ModuleName BOSH.WindowsUpdates
        Mock Start-Process { } -ModuleName BOSH.WindowsUpdates

        { Upgrade-PSVersion } | Should Not Throw

        Assert-MockCalled Test-PSVersion -Times 1 -Scope It -ModuleName BOSH.WindowsUpdates
        Assert-MockCalled Invoke-WebRequest -Times 1 -Scope It -ParameterFilter { $Uri -eq "https://go.microsoft.com/fwlink/?linkid=839516" -and $Outfile -eq "C:\provision\PS51.msu" -and $UseBasicParsing.IsPresent } -ModuleName BOSH.WindowsUpdates
        Assert-MockCalled Start-Process -Times 1 -Scope It -ParameterFilter { $FilePath -eq "C:\provision\PS51.msu" -and $ArgumentList -eq '/quiet /norestart /log:"C:\provision\psupgrade.log"' -and $Wait.IsPresent -and $Passthru.IsPresent } -ModuleName BOSH.WindowsUpdates
    }
}

Remove-Module -Name BOSH.WindowsUpdates -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
