BeforeAll {
    Import-Module ./BOSH.Sysprep.psm1
    Import-Module ../BOSH.Utils/BOSH.Utils.psm1
    Import-Module ../BOSH.Agent/BOSH.Agent.psm1


    InModuleScope BOSH.Sysprep {
        function GCESysprep
        {
        } # See: https://cloud.google.com/compute/docs/instances/windows/creating-windows-os-image
        Mock GCESysprep { }
    }
    function New-TempDir
    {
        $parent = [System.IO.Path]::GetTempPath()
        [string]$name = [System.Guid]::NewGuid()
        (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
    }
}

Describe "BOSH.Sysprep" {
    BeforeEach {
        Mock -ModuleName BOSH.Sysprep Write-Log { }
    }

    Describe "Invoke-Sysprep" {
        BeforeEach {
            Mock -ModuleName BOSH.Sysprep Stop-Computer { }
            Mock -ModuleName BOSH.Sysprep Start-Process { }

            Mock -ModuleName BOSH.Sysprep -CommandName Get-OSVersion { "windows2019" }
            Mock -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy { }
        }

        Context "when not provided an IaaS" {
            It "throws" {
                { Invoke-Sysprep -OsVersion "windows2019" } | Should -Throw "Provide the IaaS this stemcell will be used for"
            }
        }

        Context "when provided an invalid Iaas" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep -CommandName Set-NTP-Max-PhaseCorrection-Values { }
            }

            It "throws" {
                { Invoke-Sysprep -IaaS "OpenShift" -SkipLGPO -OsVersion "windows2019" } | Should -Throw "Invalid IaaS 'OpenShift' supported platforms are: AWS, Azure, GCP and Vsphere"
            }
        }

        Context "for AWS" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep Set-NTP-Max-PhaseCorrection-Values { }

                Mock -ModuleName BOSH.Sysprep Disable-AgentService { }
                Mock -ModuleName BOSH.Sysprep Update-AWS-LaunchConfigJSON { }
                Mock -ModuleName BOSH.Sysprep Update-AWS-UnattendedXML { }
                Mock -ModuleName BOSH.Sysprep Enable-AWS-Sysprep { }
            }

            It "disables the bosh agent service, and sets a local secrity policy" {
                { Invoke-Sysprep -IaaS "aws" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Disable-AgentService
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy
            }

            It "updates launchconfig.json, unattended.xml and calls Enable-AWS-Sysprep" {
                { Invoke-Sysprep -Iaas "aws" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Update-AWS-LaunchConfigJSON
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Update-AWS-UnattendedXML
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-AWS-Sysprep
            }

            Context "when '-SkipLGPO' is set" {
                It "skips local policy update if -SkipLGPO is set" {
                    { Invoke-Sysprep -Iaas "aws" -SkipLGPO } | Should -Not -Throw

                    Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy -Times 0
                }
            }
        }

        Context "for GCP" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep Set-NTP-Max-PhaseCorrection-Values { }

                Mock -ModuleName BOSH.Sysprep Disable-AgentService { }
                Mock -ModuleName BOSH.Sysprep Create-GCP-UnattendXML { }
                Mock -ModuleName BOSH.Sysprep GCESysprep { }
            }

            It "disables the bosh agent service, and sets a local secrity policy" {
                { Invoke-Sysprep -IaaS "gcp" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Disable-AgentService
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy
            }

            It "disables the bosh agent service, creates an unattend.xml file, and calls Google's sysprep command" {
                { Invoke-Sysprep -IaaS "gcp" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Create-GCP-UnattendXML
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName GCESysprep
            }

            Context "when '-SkipLGPO' is set" {
                It "skips local policy update if -SkipLGPO is set" {
                    { Invoke-Sysprep -Iaas "gcp" -SkipLGPO } | Should -Not -Throw

                    Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy -Times 0
                }
            }
        }

        Context "for vSphere" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep Set-NTP-Max-PhaseCorrection-Values { }

                Mock -ModuleName BOSH.Sysprep Disable-AgentService { }
                Mock -ModuleName BOSH.Sysprep Create-vSphere-UnattendXML { }
                Mock -ModuleName BOSH.Sysprep Invoke-Expression { }
            }

            It "disables the bosh agent service, and sets a local secrity policy" {
                { Invoke-Sysprep -IaaS "vsphere" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Disable-AgentService
                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Enable-LocalSecurityPolicy
            }

            It "creates an unattend.xml file" {
                { Invoke-Sysprep -IaaS "vsphere" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Create-vSphere-UnattendXML -ParameterFilter {
                    $NewPassword -ne $null -and $ProductKey -ne $null -and $Organization -ne $null -and $Owner -ne $null
                }
            }

            It "invokes windows sysprep, passing unattended.xml with the expected flags" {
                { Invoke-Sysprep -IaaS "vsphere" } | Should -Not -Throw

                Should -Invoke -ModuleName BOSH.Sysprep -CommandName Invoke-Expression -ParameterFilter {
                    $Command -eq 'C:/windows/system32/sysprep/sysprep.exe /generalize /oobe /unattend:"C:/Windows/Panther/Unattend/unattend.xml" /quiet /shutdown'
                }
            }
        }
    }

    Describe "Create-vSphere-UnattendXML" {
        BeforeEach {
            $UnattendDestination = (New-TempDir)
            $NewPassword = "NewPassword"
            $ProductKey = "ProductKey"
            $Organization = "Organization"
            $Owner = "Owner"
        }

        AfterEach {
            Remove-Item -Recurse -Force $UnattendDestination
        }

        It "places the generated Unattend file in the specified directory" {
            {
                Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                -NewPassword $NewPassword `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
            } | Should -Not -Throw
            Test-Path (Join-Path $UnattendDestination "unattend.xml") | Should -Be $True
        }

        It "handles special chars in passwords" {
            $NewPassword = "<!--Password123"
            {
                Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                -NewPassword $NewPassword `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
            } | Should -Not -Throw

            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath

            $encodedPassword = $unattendXML.unattend.settings.component.UserAccounts.AdministratorPassword.Value
            [system.text.encoding]::Unicode.GetString([system.convert]::Frombase64string($encodedPassword)) | Should -Be ($NewPassword + "AdministratorPassword")
        }

        It "handles null for NewPassword" {
            {
                Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                -NewPassword $null `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
            } | Should -Not -Throw

            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath

            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            $unattendXML.SelectSingleNode("//ns:UserAccounts", $ns) | Should -Be $Null
        }

        It "handles empty string for NewPassword" {
            {
                Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                -NewPassword "" `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
            } | Should -Not -Throw

            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath

            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            $unattendXML.SelectSingleNode("//ns:UserAccounts", $ns) | Should -Be $Null
        }

        It "handles not providing NewPassword" {
            {
                Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
            } | Should -Not -Throw

            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath

            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            $unattendXML.SelectSingleNode("//ns:UserAccounts", $ns) | Should -Be $Null
        }

        Context "the generated Unattend file" {
            BeforeEach {
                {
                    Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                     -NewPassword $NewPassword `
                     -ProductKey $ProductKey `
                     -Organization $Organization `
                     -Owner $Owner
                } | Should -Not -Throw
                $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
                [xml]$unattendXML = Get-Content -Path $unattendPath
                $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
                $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            }

            It "contains a Product Key, Organization, and Owner when Product Key is provided" {
                $unattendXML.SelectSingleNode("//ns:ProductKey", $ns).'#text' | Should -Be $ProductKey
                $unattendXML.SelectSingleNode("//ns:RegisteredOrganization", $ns).'#text' | Should -Be $Organization
                $unattendXML.SelectSingleNode("//ns:RegisteredOwner", $ns).'#text' | Should -Be $Owner
            }

            It "when Product Key is not provided, there is no Product Key, Organization, or Owner" {
                {
                    Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                    -NewPassword $NewPassword
                } | Should -Not -Throw
                [xml]$unattendXML = Get-Content -Path $unattendPath
                $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
                $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
                $unattendXML.SelectSingleNode("//ns:ProductKey", $ns).'#text' | Should -Be $Null
            }

            It "when Product Key is not provided: Organization and Owner are not removed" {
                {
                    Create-vSphere-UnattendXML -UnattendDestination $UnattendDestination `
                    -NewPassword $NewPassword -Organization 'Test-Org' -Owner 'Test-Owner'
                } | Should -Not -Throw
                [xml]$unattendXML = Get-Content -Path $unattendPath
                $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
                $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
                $unattendXML.SelectSingleNode("//ns:RegisteredOrganization", $ns).'#text' | Should -Be 'Test-Org'
                $unattendXML.SelectSingleNode("//ns:RegisteredOwner", $ns).'#text' | Should -Be 'Test-Owner'
            }
        }
    }

    Describe "Create-GCP-UnattendXML" {
        BeforeEach {
            $UnattendDestination = (New-TempDir)
        }
        AfterEach {
            Remove-Item -Recurse -Force $UnattendDestination
        }

        It "places the generated Unattend file in the specified directory" {
            {
                Create-GCP-UnattendXML -UnattendDestination $UnattendDestination
            } | Should -Not -Throw

            Test-Path (Join-Path $UnattendDestination "unattended.xml") | Should -Be $True
        }

        It "sets the timezone to UTC" {
            {
                Create-GCP-UnattendXML -UnattendDestination $UnattendDestination
            } | Should -Not -Throw

            $unattendPath = (Join-Path $UnattendDestination "unattended.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath
            $timezones = $unattendXML.unattend.settings.component.TimeZone |
                    Where-Object { $_ -ne $null }

            $timezones.count | Should -BeGreaterOrEqual 1
            $timezones | ForEach-Object { $_ | Should -Be "UTC" }
        }
    }

    Describe "Set-NTP-Max-PhaseCorrection-Values" {
        It "Sets registry keys that allow the clock to be synced when delta is greater than 15 hours" {
            $oldMaxNegPhaseCorrection = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxNegPhaseCorrection'
            $oldMaxPosPhaseCorrection = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxPosPhaseCorrection'

            { Set-NTP-Max-PhaseCorrection-Values } | Should -Not -Throw

            $maxValue = [uint32]::MaxValue
            (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxNegPhaseCorrection' | Should -Be $maxValue
            (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxPosPhaseCorrection' | Should -Be $maxValue

            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name 'MaxNegPhaseCorrection' -Value $oldMaxNegPhaseCorrection
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name 'MaxPosPhaseCorrection' -Value $oldMaxPosPhaseCorrection
        }
    }

    Describe "Enable-LocalSecurityPolicy" {
        BeforeEach {
            Mock -ModuleName BOSH.Sysprep -CommandName Get-OSVersion { "windows2019" }

            $expectedPolicyDir = Join-Path $PSScriptRoot "cis-merge-2019"
            $domainSysVolDir = "$expectedPolicyDir/DomainSysvol"
            $machinePolicyDir = "$domainSysVolDir/GPO/Machine"
            $userPolicyDir = "$domainSysVolDir/GPO/User"

            $lgpoExePath = "C:\Windows\LGPO.exe"
            Mock -ModuleName BOSH.Sysprep Test-Path { $True } -ParameterFilter { $Path -eq $lgpoExePath }
        }

        It "invokes LGPO.exe the expected files" {
            $invokedExpressions = New-Object System.Collections.ArrayList
            Mock -ModuleName BOSH.Sysprep -CommandName Invoke-Expression {
                $invokedExpressions.Add($Command)
                return 0
            }

            { Enable-LocalSecurityPolicy } | Should -Not -Throw

            Should -Invoke -ModuleName BOSH.Sysprep -CommandName Invoke-Expression -Times 3
            $invokedExpressions | Should -Be @(
                "$lgpoExePath /r '$machinePolicyDir/registry.txt' /w '$machinePolicyDir/registry.pol'",
                "$lgpoExePath /r '$userPolicyDir/registry.txt' /w '$userPolicyDir/registry.pol'",
                "$lgpoExePath /g '$domainSysVolDir' /v"
            )
        }

        Context "when OS is unknown" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep -CommandName Get-OSVersion { "windows-unknown" }
            }

            It "throws an error" {
                { Enable-LocalSecurityPolicy } | Should -Throw
            }
        }

        Context "when LGPO.exe is not found" {
            BeforeEach {
                Mock -ModuleName BOSH.Sysprep Test-Path { $False } -ParameterFilter { $Path -eq "C:\Windows\LGPO.exe" }
            }

            It "throws an error" {
                { Enable-LocalSecurityPolicy } | Should -Throw
            }
        }
    }
}
