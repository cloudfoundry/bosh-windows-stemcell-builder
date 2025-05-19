# We import module BOSH.SSH to ensure that we get the Install-SSHD function it defines. Starting with
# OpenSSH 9.1, there is a conflicting install-sshd.ps1 script that takes precedence instead if you do
# not load the module.
Import-Module -Name BOSH.SSH
. ./AutomationHelpers.ps1

Describe "Setup" {
    BeforeEach {
        [System.Collections.ArrayList]$provisionerCalls = @()

        Mock Validate-OSVersion { $provisionerCalls.Add("Validate-OSVersion") }
        Mock Check-Dependencies { $provisionerCalls.Add("Check-Dependencies") }

        Mock RunQuickerDism { }

        Mock CopyPSModules { $provisionerCalls.Add("CopyPSModules") }
        Mock Set-RegKeys { $provisionerCalls.Add("Set-RegKeys") }
        Mock InstallBoshAgent { $provisionerCalls.Add("InstallBoshAgent") }
        Mock InstallOpenSSH { $provisionerCalls.Add("InstallOpenSSH") }
        Mock Extract-LGPO { $provisionerCalls.Add("Extract-LGPO") }
        Mock Install-SecurityPoliciesAndRegistries { $provisionerCalls.Add("Install-SecurityPoliciesAndRegistries") }
        Mock Enable-SSHD { $provisionerCalls.Add("Enable-SSHD") }

        Mock Install-WUCerts { $provisionerCalls.Add("Install-WUCerts") }

        Mock InstallCFFeatures { $provisionerCalls.Add("InstallCFFeatures") }
        Mock RemoveAvailableWindowsFeatures { }
        Mock Create-VersionFile { $provisionerCalls.Add("Create-VersionFile") }
        Mock Restart-Computer { $provisionerCalls.Add("Restart-Computer") }

        if (!(Get-Command "Restart-Computer" -errorAction SilentlyContinue))
        {
            function Restart-Computer() {
                throw "what is happening I should never be invoked"
            }
        }
    }

    It "validates OS version first" {
        Setup

        Assert-MockCalled -CommandName Validate-OSVersion
        $provisionerCalls.IndexOf("Validate-OSVersion") | Should -Be 0
    }

    It "checks dependencies" {
        Setup

        Assert-MockCalled -CommandName Check-Dependencies
        $provisionerCalls.IndexOf("Check-Dependencies") | Should -Be 1
    }

    It "copy PSModules is the first provisioner called" {
        Setup

        Assert-MockCalled -CommandName CopyPSModules
        $provisionerCalls.IndexOf("CopyPSModules") | Should -Be 2
    }

    It "sets registry keys to stop zombie load and meltdown exploits" {
        Setup

        Assert-MockCalled -CommandName Set-RegKeys
    }

    It "installs BoshAgent" {
        Setup

        Assert-MockCalled -CommandName InstallBoshAgent
    }

    It "installs OpenSSH before enabling SSH" {
        Setup

        Assert-MockCalled -CommandName InstallOpenSSH
        $provisionerCalls.IndexOf("InstallOpenSSH") | Should -BeGreaterOrEqual 0
        $provisionerCalls.IndexOf("InstallOpenSSH") | Should -BeLessThan $provisionerCalls.IndexOf("Enable-SSHD")
    }

    It "enables SSHD" {
        Setup

        Assert-MockCalled -CommandName Enable-SSHD
    }

    It "installs SecurityPoliciesAndRegistries after extracting LGPO" {
        Setup

        Assert-MockCalled -CommandName Install-SecurityPoliciesAndRegistries

        $provisionerCalls.IndexOf("Extract-LGPO") | Should -BeGreaterOrEqual 0
        $provisionerCalls.IndexOf("Extract-LGPO") | Should -BeLessThan $provisionerCalls.IndexOf("Install-SecurityPoliciesAndRegistries")
    }

    It "extracts LGPO before enabling SSH" {
        Setup

        Assert-MockCalled -CommandName Extract-LGPO

        $provisionerCalls.IndexOf("Extract-LGPO") | Should -BeGreaterOrEqual 0
        $provisionerCalls.IndexOf("Extract-LGPO") | Should -BeLessThan $provisionerCalls.IndexOf("Enable-SSHD")
    }

    It "installs CFFeatures" {
        Setup

        Assert-MockCalled -CommandName InstallCFFeatures
    }

    It "installs WU certs" {
        Setup

        Assert-MockCalled -CommandName Install-WUCerts
    }

    Context "when Install-WUCerts helper fails" {
        It "fails gracefully" {
            Mock Install-WUCerts { throw "Something went wrong trying to Install-WUCerts" }
            Mock Write-Log { }
            Mock Write-Warning { }

            { Setup } | Should -Not -Throw

            Assert-MockCalled Install-WUCerts -Times 1 -Scope It
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Something went wrong trying to Install-WUCerts" }
            Assert-MockCalled Write-Warning -Times 1 -Scope It -ParameterFilter {$Message -eq "Failed to retrieve updated root certificates from the public Windows Update Server. This should not impact the successful execution of stembuild construct. If your root certificates are out of date, Diego cells running on VMs built from this stemcell may not be able to make outbound network connections." }
        }

        Context "when the '-FailOnInstallWUCerts' flag is passed" {
            It "throws an error" {
                Mock Install-WUCerts { throw "Something went wrong trying to Install-WUCerts" }
                Mock Write-Log { }

                { Setup -FailOnInstallWUCerts } | Should -Throw

                Assert-MockCalled Install-WUCerts -Times 1 -Scope It
                Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Something went wrong trying to Install-WUCerts" }
            }
        }
    }

    It "creates a version file" {
        Setup

        Assert-MockCalled -CommandName Create-VersionFile
    }

    It "restarts as the last command" {
        Setup

        Assert-MockCalled -CommandName Restart-Computer
        $lastIndex = $provisionerCalls.Count - 1
        $provisionerCalls.IndexOf("Restart-Computer") | Should -Be $lastIndex
    }
}

Describe "PostReboot" {
    BeforeEach {
        [System.Collections.ArrayList]$postRebootCalls = @()
        Mock InstallCFCell { $postRebootCalls.Add("InstallCFCell")}
        Mock CleanUpVM { $postRebootCalls.Add("CleanUpVM")}
        Mock SysprepVM { $postRebootCalls.Add("SysprepVM")}
        Mock Stop-Computer {$postRebootCalls.Add("Stop-Computer")}
        Mock RunQuickerDism { }
    }

    It "installs cf cell before cleaning up the VM" {
        PostReboot
        Assert-MockCalled -CommandName InstallCFCell
        $postRebootCalls.IndexOf("InstallCFCell") | Should -BeLessThan $postRebootCalls.IndexOf("CleanUpVM")
    }

    It "cleans up vm before sysprep" {
        PostReboot
        Assert-MockCalled -CommandName CleanUpVM
        $postRebootCalls.IndexOf("CleanUpVM") | Should -BeLessThan $postRebootCalls.IndexOf("SysprepVM")
    }

    It "syspreps as the last command" {
        PostReboot -Organization "org" -Owner "owner" -SkipRandomPassword:$false
        Assert-MockCalled -CommandName SysprepVM
        Assert-MockCalled -CommandName SysprepVM -ParameterFilter {
            $Organization -eq "org" -and
                    $Owner -eq "owner" -and
                    $SkipRandomPassword -eq $false
        }
        $lastIndex = $postRebootCalls.Count - 1
        $postRebootCalls.IndexOf("SysprepVM") | Should -Be $lastIndex
    }
}

Describe "CopyPSModules" {
    It "can copy PS Modules to target directory" {
        Mock Write-Log { }
        Mock Expand-Archive { }

        { CopyPSModules } | Should -Not -Throw

        Assert-MockCalled Expand-Archive -Times 1 -Scope It -ParameterFilter { $LiteralPath -eq ".\bosh-psmodules.zip" -and $DestinationPath -eq "C:\Program Files\WindowsPowerShell\Modules\" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Succesfully migrated Bosh Powershell modules to destination dir" }
    }

    It "fails gracefully when expanding archive fails" {
        Mock Expand-Archive { throw "Expand-Archive failed because something went wrong" }
        Mock Write-Log { }

        { CopyPSModules } | Should -Throw "Expand-Archive failed because something went wrong"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Expand-Archive failed because something went wrong" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to copy Bosh Powershell Modules into destination dir. See 'c:\provision\log.log' for more info." }
    }
}

Describe "InstallCFFeatures" {
    It "executes the Install-CFFeatures2016 powershell cmdlet" {
        Mock Install-CFFeatures2016 { }
        Mock Write-Log { }

        { InstallCFFeatures } | Should -Not -Throw

        Assert-MockCalled Install-CFFeatures2016 -Times 1 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Successfully installed CF features" }
    }

    It "fails gracefully when installing CF Features" {
        Mock Install-CFFeatures2016 { throw "Something terrible happened while attempting to install a CF feature" }
        Mock Write-Log { }

        { InstallCFFeatures } | Should -Throw "Something terrible happened while attempting to install a CF feature"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to install a CF feature" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to install the CF features. See 'c:\provision\log.log' for more info." }
    }
}


Describe "InstallCFCell" {
    It "executes the Protect-CFCell powershell cmdlet" {
        Mock Protect-CFCell { }
        Mock Write-Log { }

        { InstallCFCell } | Should -Not -Throw

        Assert-MockCalled Protect-CFCell -Times 1
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Succesfully ran Protect-CFCell" }
    }

    It "fails gracefully when Protect-CFCell powershell cmdlet fails" {
        Mock Protect-CFCell { throw "Something terrible happened while attempting to execute Protect-CFCell" }
        Mock Write-Log { }

        { InstallCFCell } | Should -Throw "Something terrible happened while attempting to execute Protect-CFCell"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Protect-CFCell" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to execute Protect-CFCell powershell cmdlet. See 'c:\provision\log.log' for more info." }
    }
}

Describe "InstallBoshAgent" {
    It "executes the Install-Agent powershell cmdlet" {
        Mock Install-Agent { }
        Mock Write-Log { }

        { InstallBoshAgent } | Should -Not -Throw


        Assert-MockCalled Install-Agent -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $agentZipPath -eq ".\agent.zip" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Bosh agent successfully installed" }
    }

    It "fails gracefully when Install-Agent powershell cmdlet fails" {
        Mock Install-Agent { throw "Something terrible happened while attempting to execute Install-Agent" }
        Mock Write-Log { }

        { InstallBoshAgent } | Should -Throw "Something terrible happened while attempting to execute Install-Agent"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Install-Agent" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to execute Install-Agent powershell cmdlet. See 'c:\provision\log.log' for more info." }
    }
}

Describe "InstallOpenSSH" {
    It "executes the Install-SSHD powershell cmdlet" {
        Mock Install-SSHD { }
        Mock Write-Log { }

        { InstallOpenSSH } | Should -Not -Throw


        Assert-MockCalled Install-SSHD -Times 1 -Scope It -ParameterFilter { $SSHZipFile -eq ".\OpenSSH-Win64.zip" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "OpenSSH successfully installed" }
    }

    It "fails gracefully when Install-SSHD powershell cmdlet fails" {
        Mock Install-SSHD { throw "Something terrible happened while attempting to execute Install-SSHD" }
        Mock Write-Log { }

        { InstallOpenSSH } | Should -Throw "Something terrible happened while attempting to execute Install-SSHD"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Install-SSHD" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to execute Install-SSHD powershell cmdlet. See 'c:\provision\log.log' for more info." }
    }
}

Describe "CleanUpVM" {
    It "executes the Optimize-Disk and Compress-Disk powershell cmdlet" {
        Mock Optimize-Disk { }
        Mock Compress-Disk { }
        Mock Write-Log { }

        { CleanUpVM } | Should -Not -Throw

        Assert-MockCalled Optimize-Disk -Times 1 -Scope It
        Assert-MockCalled Compress-Disk -Times 1 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Successfully cleaned up the VM's disk" }
    }

    It "fails gracefully when Optimize-Disk powershell cmdlet fails" {
        Mock Optimize-Disk { throw "Something terrible happened while attempting to execute Optimize-Disk" }
        Mock Compress-Disk { }
        Mock Write-Log { }

        { CleanUpVM } | Should -Throw "Something terrible happened while attempting to execute Optimize-Disk"

        Assert-MockCalled Optimize-Disk -Times 1 -Scope It
        Assert-MockCalled Compress-Disk -Times 0 -Scope It

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Optimize-Disk" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to clean up the VM's disk. See 'c:\provision\log.log' for more info." }
    }

    It "fails gracefully when Compress-Disk powershell cmdlet fails" {
        Mock Optimize-Disk { }
        Mock Compress-Disk { throw "Something terrible happened while attempting to execute Compress-Disk" }
        Mock Write-Log { }

        { CleanUpVM } | Should -Throw "Something terrible happened while attempting to execute Compress-Disk"

        Assert-MockCalled Optimize-Disk -Times 1 -Scope It
        Assert-MockCalled Compress-Disk -Times 1 -Scope It

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Compress-Disk" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to clean up the VM's disk. See 'c:\provision\log.log' for more info." }
    }
}

Describe "SysprepVM" {
    BeforeEach {
        Mock Invoke-Sysprep { }
        Mock GenerateRandomPassword { "SomeRandomPassword" }
        Mock Write-Log { }
    }
    It "copies LGPO to the correct destination and executes the Invoke-Sysprep powershell cmdlet" {

        { SysprepVM } | Should -Not -Throw

        Assert-MockCalled GenerateRandomPassword -Times 1 -Scope It
        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" }
    }

    It "executes the Invoke-Sysprep powershell cmdlet with owner parameter set when an owner string is provided" {

        { SysprepVM -Owner "some owner" } | Should -Not -Throw

        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" -and $Owner -eq "some owner" -and $Organization -eq "" }
    }

    It "executes the Invoke-Sysprep powershell cmdlet with organization parameter set when an organization string is provided" {

        { SysprepVM -Organization "some org" } | Should -Not -Throw

        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" -and $Organization -eq "some org" -and $Owner -eq "" }
    }

    It "executes the Invoke-Sysprep powershell cmdlet with owner parameter set when an organization string has line breaks" {

        { SysprepVM -Owner "some `r`n org" } | Should -Not -Throw

        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" -and $Owner -eq "some `r`n org" -and $Organization -eq "" }
    }

    It "executes the Invoke-Sysprep powershell cmdlet with owner & organization parameter set when an owner & organization string is provided" {

        { SysprepVM -Owner "some owner" -Organization "some org" } | Should -Not -Throw

        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" -and $Owner -eq "some owner" -and $Organization -eq "some org" }
    }

    It "fails gracefully when Invoke-Sysprep powershell cmdlet fails" {
        Mock Invoke-Sysprep { throw "Invoke-Sysprep failed because something went wrong" }

        { SysprepVM } | Should -Throw "Invoke-Sysprep failed because something went wrong"

        Assert-MockCalled GenerateRandomPassword -Times 1 -Scope It
        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq "SomeRandomPassword" }

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Invoke-Sysprep failed because something went wrong" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to Sysprep the VM's. See 'c:\provision\log.log' for more info." }
    }

    It "fails gracefully when GenerateRandomPassword function fails" {
        Mock GenerateRandomPassword { throw "GenerateRandomPassword failed because something went wrong" }

        { SysprepVM } | Should -Throw "GenerateRandomPassword failed because something went wrong"

        Assert-MockCalled GenerateRandomPassword -Times 1 -Scope It
        Assert-MockCalled Invoke-Sysprep -Times 0 -Scope It

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "GenerateRandomPassword failed because something went wrong" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to Sysprep the VM's. See 'c:\provision\log.log' for more info." }
    }

    It "doesn't generate a new password when -SkipRandomPassword set to true" {

        { SysprepVM -SkipRandomPassword $True} | Should -Not -Throw

        Assert-MockCalled Invoke-Sysprep -Times 1 -Scope It -ParameterFilter { $IaaS -eq "vsphere" -and $NewPassword -eq $null }
    }
}

Describe "GenerateRandomPassword" {

    It "generates a valid password" {
        Mock Get-Random { "changeMe123!".ToCharArray() }
        Mock Valid-Password { $True }
        Mock Write-Log{ }
        $result = ""
        { GenerateRandomPassword | Set-Variable -Name "result" -Scope 1 } | Should -Not -Throw
        $result | Should -BeExactly "changeMe123!"

        Assert-MockCalled Get-Random -Times 1 -Scope It
        Assert-MockCalled Valid-Password -Times 1 -Scope It -ParameterFilter { $Password -eq "changeMe123!" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Successfully generated password" }
    }

    It "fails to generate a valid password after 200 tries" {
        Mock Get-Random { "changeMe123!".ToCharArray() }
        Mock Valid-Password { $False }
        Mock Write-Log{ }

        { GenerateRandomPassword } | Should -Throw "Unable to generate a valid password after 200 attempts"

        Assert-MockCalled Get-Random -Times 200 -Scope It
        Assert-MockCalled Valid-Password -Times 200 -Scope It -ParameterFilter { $Password -eq "changeMe123!" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to generate password after 200 attempts" }
    }
}

Describe "Valid-Password" {

    Context "returns true with a valid password input of at least 8 characters" {
        It "that contains at least 1 digit, 1 special, and 1 lower case character" {
            Valid-Password "changeme123!" | Should -Be $True
        }

        It "that contains at least 1 digit, 1 special, and 1 upper case character" {
            Valid-Password "CHANGEME123!" | Should -Be $True
        }

        It "that contains at least 1 digit, 1 upper case, and 1 lower case character" {
            Valid-Password "Changeme123" | Should -Be $True
        }

        It "that contains at least 1 special, 1 upper case, and 1 lower case character" {
            Valid-Password "Changeme!" | Should -Be $True
        }
    }

    Context "returns false with a invalid password input" {
        It "that contains less than 8 characters" {
            Valid-Password "a" | Should -Be $false
        }

        It "that contains only upper and lower case characters" {
            Valid-Password "Changemenow" | Should -Be $false
        }

        It "that contains only digits and special characters" {
            Valid-Password "123!456*789?" | Should -Be $false
        }

        It "that contains only digits and upper case characters" {
            Valid-Password "CHANGE123ME" | Should -Be $false
        }

        It "that contains only lower case and special characters" {
            Valid-Password "qwerty!@#$%%" | Should -Be $false
        }

        It "that contains an invalid character" {
            Valid-Password "JoyeuxNoël123!" | Should -Be $false
        }

        It "that contains a whitespace character" {
            Valid-Password "JoyeuxNoel 123!" | Should -Be $false
        }
    }
}

Describe "Is-Special" {
    It "returns true when given a valid special character" {
        $CharList = "!`"#$%&'()*+,-./:;<=>?@[\]^_``{|}~".ToCharArray()
        foreach ($c in $CharList)
        {
            Is-Special $c | Should -Be $true
        }
    }

    It "returns false when given an alpha numeric characters" {
        Is-Special "a" | Should -Be $False
        Is-Special "5" | Should -Be $False
        Is-Special "T" | Should -Be $False
    }

    It "returns false when given whitespace character" {
        Is-Special " " | Should -Be $False
    }
}

function GenerateDepJson
{
    param ([parameter(Mandatory = $true)] [string]$file1Sha,
        [parameter(Mandatory = $true)] [string]$file2Sha,
        [parameter(Mandatory = $true)] [string]$file3Sha
    )

    return "{""file1.zip"":{""sha"":""$file1Sha"",""version"":""1.0""},""file2.zip"":{""sha"":""$file2Sha"",""version"":""1.0-alpha""},""file3.exe"":{""sha"":""$file3Sha"",""version"":""3.0""}}"
}

Describe "Check-Dependencies" {
    BeforeEach {
        Mock Write-Log { }

        $file1Hash = @{
            Algorithm = "SHA256"
            Hash = "hashOne"
            Path = "$PSScriptRoot/file1.zip"
        }
        $file2Hash = @{
            Algorithm = "SHA256"
            Hash = "hashTwo"
            Path = "$PSScriptRoot/file2.zip"
        }
        $file3Hash = @{
            Algorithm = "SHA256"
            Hash = "hashThree"
            Path = "$PSScriptRoot/file3.exe"
        }

        Mock Get-FileHash { New-Object PSObject -Property $file1Hash } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
        Mock Get-FileHash { New-Object PSObject -Property $file2Hash } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
        Mock Get-FileHash { New-Object PSObject -Property $file3Hash } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

        Mock Test-Path { $true } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
        Mock Test-Path { $true } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
        Mock Test-Path { $true } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

        #We specify when to throw the exception to prevent other test from being polluted when calling Convert-FromJson
        Mock ConvertFrom-Json { throw "Invalid JSON primitive: bad-json-format" } -ParameterFilter { $InputObject -match "bad-json-format" }
    }


    It "successfully checks all required files are available and have the correct SHAs" {
        Mock Get-Content { GenerateDepJson "hashOne" "hashTwo" "hashThree" }

        { Check-Dependencies } | Should -Not -Throw

        Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }

        Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
        Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
        Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

        Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
        Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
        Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found all dependencies" }
    }

    Context "fails gracefully if the dependency file" {
        It "is not present" {
            Mock Get-Content { throw "File not found" }

            { Check-Dependencies } | Should -Throw "File not found"

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "File not found" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }

        }

        It "is empty" {
            Mock Get-Content { "" }

            { Check-Dependencies } | Should -Throw "Dependency file is empty"

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Dependency file is empty" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }
        }

        It "contains an empty json object" {
            Mock Get-Content { "{}" }

            { Check-Dependencies } | Should -Throw "Dependency file is empty"

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Dependency file is empty" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }
        }

        It "content is badly formatted" {
            Mock Get-Content { "bad-json-format" }

            { Check-Dependencies } | Should -Throw "Invalid JSON primitive: bad-json-format"

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Invalid JSON primitive: bad-json-format" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }

        }
    }

    Context "fails gracefully when checking file dependencies" {
        It "when one or more are not found" {
            Mock Get-Content { GenerateDepJson "hashOne" "hashTwo" "hashThree" }
            Mock Test-Path { $false } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Mock Test-Path { $false } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            { Check-Dependencies } | Should -Throw "One or more files are corrupted or missing."

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }

            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Get-FileHash -Times 0 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Get-FileHash -Times 0 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Write-Log -Times 0 -Scope It -ParameterFilter { $Message -like "$PSScriptRoot/file1.zip *" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file2.zip is required but was not found" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file3.exe is required but was not found" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }
        }

        It "when one or more file hashes do not match" {
            Mock Get-Content { GenerateDepJson "hashOne" "badhash2" "badhash3" }

            { Check-Dependencies } | Should -Throw "One or more files are corrupted or missing."

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }

            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Write-Log -Times 0 -Scope It -ParameterFilter { $Message -like "$PSScriptRoot/file1.zip *" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file2.zip does not have the correct hash" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file3.exe does not have the correct hash" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }
        }

        It "when one file hash does not match and another file is missing " {
            Mock Test-Path { $False } -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }
            Mock Get-Content { GenerateDepJson "hashOne" "badhash2" "hashThree" }

            { Check-Dependencies } | Should -Throw "One or more files are corrupted or missing."

            Assert-MockCalled Get-Content -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/deps.json" }

            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Get-FileHash -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Get-FileHash -Times 0 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file1.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file2.zip" }
            Assert-MockCalled Test-Path -Times 1 -Scope It -ParameterFilter { $Path -cmatch "$PSScriptRoot/file3.exe" }

            Assert-MockCalled Write-Log -Times 0 -Scope It -ParameterFilter { $Message -like "$PSScriptRoot/file1.zip *" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file2.zip does not have the correct hash" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "$PSScriptRoot/file3.exe is required but was not found" }
            Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate required dependencies. See 'c:\provision\log.log' for more info." }
        }
    }
}

Describe "Validate-OSVersion" {
    BeforeEach {
        Mock Write-Log { }

        $major2019 = 10
        $minor2019 = 0
        $build2019 = 17763
        $revision2019 = "IGNORED_REVISION_VALUE"
    }

    It "fails gracefully when the OS major version doesn't match" {
        Mock Get-OSVersionString { "$($major2019 + 1).$minor2019.$build2019.$revision2019" }

        { Validate-OSVersion } | Should -Throw "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate the OS version. See 'c:\provision\log.log' for more info." }
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It
    }

    It "fails gracefully when the OS minor version doesn't match" {
        Mock Get-OSVersionString { "$major2019.$($minor2019 + 1).$build2019.$revision2019" }

        { Validate-OSVersion } | Should -Throw "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate the OS version. See 'c:\provision\log.log' for more info." }
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It

    }

    It "fails gracefully when the OS build version doesn't match" {
        Mock Get-OSVersionString { "$major2019.$minor2019.$($build2019 + 1).$revision2019" }

        { Validate-OSVersion } | Should -Throw "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "OS Version Mismatch: Please use Windows Server 2019 or 2022 as the OS on your targeted VM" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate the OS version. See 'c:\provision\log.log' for more info." }
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It
    }

    It "successfully validates the OS when it is Windows Server 2019" {
        Mock Get-OSVersionString { "$major2019.$minor2019.$build2019.$revision2019" }

        { Validate-OSVersion } | Should -Not -Throw

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Found correct OS version: Windows Server 2019" }
        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It
    }

    It "fails gracefully when an exception is received when getting OS version" {
        Mock Get-OSVersionString { throw "Could not fetch OS version" }
        Mock Write-Log

        { Validate-OSVersion } | Should -Throw "Could not fetch OS version"

        Assert-MockCalled Get-OSVersionString -Times 1 -Scope It

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -cmatch "Could not fetch OS version" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to validate the OS version. See 'c:\provision\log.log' for more info." }
    }
}

Describe "Set-RegKeys" {
    It "Successfully sets the registry keys." {
        Mock New-ItemProperty{ }
	Mock Test-Path { $True }
        { Set-RegKeys } | Should -Not -Throw
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat' -and $Value -eq 0 -and $Name -eq 'cadca5fe-87d3-4b96-b7fb-a231484277cc' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization' -and $Value -eq 1.0 -and $Name -eq 'MinVmVersionForCpuBasedMitigations' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -and $Value -eq 3 -and $Name -eq 'FeatureSettingsOverrideMask' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -and $Value -eq 72 -and $Name -eq 'FeatureSettingsOverride' }
    }

    It "Successfully sets the registry keys including non-existing one. " {
	Mock New-Item { }
	Mock New-ItemProperty{ }
	Mock Test-Path { $False }
        { Set-RegKeys } | Should -Not -Throw
        Assert-MockCalled New-Item -ParameterFilter{ $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat' } -Times 1
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat' -and $Value -eq 0 -and $Name -eq 'cadca5fe-87d3-4b96-b7fb-a231484277cc' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization' -and $Value -eq 1.0 -and $Name -eq 'MinVmVersionForCpuBasedMitigations' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -and $Value -eq 3 -and $Name -eq 'FeatureSettingsOverrideMask' }
        Assert-MockCalled New-ItemProperty -ParameterFilter{ $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -and $Value -eq 72 -and $Name -eq 'FeatureSettingsOverride' }
    }
}

Describe "Install-SecurityPoliciesAndRegistries" {

    BeforeEach {
        function Set-InternetExplorerRegistries{ }
    }

    It "executes the Set-InternetExplorerRegistries powershell cmdlet if the os verison is 2019" {
        $osVersion2019 = "10.0.17763.0"
        Mock Set-InternetExplorerRegistries { }
        Mock Write-Log { }
        Mock Get-OSVersionString { $osVersion2019 }

        { Install-SecurityPoliciesAndRegistries } | Should -Not -Throw

        Assert-MockCalled Set-InternetExplorerRegistries -Times 1 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Succesfully ran Set-InternetExplorerRegistries" }
    }

    It "does not execute the Set-InternetExplorerRegistries powershell cmdlet if the os version is not 2019" {
        Mock Set-InternetExplorerRegistries { }
        Mock Write-Log { }
        Mock Get-OSVersionString { "NOT_2019" }

        { Install-SecurityPoliciesAndRegistries } | Should -Not -Throw

        Assert-MockCalled Set-InternetExplorerRegistries -Times 0 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Did not run Set-InternetExplorerRegistries because OS version was not 2019 or 2022" }

    }

    It "fails gracefully when Set-InternetExplorerRegistries powershell cmdlet fails" {
        $osVersion2019 = "10.0.17763.0"
        Mock Get-OSVersionString { $osVersion2019 }
        Mock Set-InternetExplorerRegistries { throw "Something terrible happened while attempting to execute Set-InternetExplorerRegistries" }
        Mock Write-Log { }

        { Install-SecurityPoliciesAndRegistries  } | Should -Throw "Something terrible happened while attempting to execute Set-InternetExplorerRegistries"

        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Something terrible happened while attempting to execute Set-InternetExplorerRegistries" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter { $Message -eq "Failed to execute Set-InternetExplorerRegistries powershell cmdlet. See 'c:\provision\log.log' for more info." }
    }

}

function CreateFakeOpenSSHZip
{
    param([string]$dir, [string]$installScriptSpyStatus, [string]$fakeZipPath)

    mkdir "$dir\OpenSSH-Win64"
    $installSpyBehavior = "echo installed > $installScriptSpyStatus"
    echo $installSpyBehavior > "$dir\OpenSSH-Win64\install-sshd.ps1"
    echo "fake sshd" > "$dir\OpenSSH-Win64\sshd.exe"

    Compress-Archive -Force -Path "$dir\OpenSSH-Win64" -DestinationPath $fakeZipPath
}

function CreateFakeLGPOZip
{
    param([string]$dir, [string]$fakeZipPath)

    New-Item -ItemType Directory "$dir\LGPO\LGPO_30"
    echo "fake lgpo" > "$dir\LGPO\LGPO_30\LGPO.exe"

    Compress-Archive -Force -Path "$dir\LGPO\*" -DestinationPath $fakeZipPath
}

Describe "Enable-SSHD" {
    BeforeEach {
        Mock Set-Service { }
        Mock Run-LGPO { }

        $guid = $( New-Guid ).Guid
        $TMP_DIR = "$env:TEMP\BOSH.SSH.Tests-$guid"

        $FAKE_ZIP = "$TMP_DIR\OpenSSH-TestFake.zip"
        $INSTALL_SCRIPT_SPY_STATUS = "$TMP_DIR\install-script-status"

        CreateFakeOpenSSHZip -dir $TMP_DIR -installScriptSpyStatus $INSTALL_SCRIPT_SPY_STATUS -fakeZipPath $FAKE_ZIP

        mkdir -p "$TMP_DIR\Windows\Temp"
        echo "fake LGPO" > "$TMP_DIR\Windows\LGPO.exe"

        $ORIGINAL_WINDIR = $env:WINDIR
        $env:WINDIR = "$TMP_DIR\Windows"

        $ORIGINAL_PROGRAMDATA = $env:ProgramData
        $env:PROGRAMDATA = "$TMP_DIR\ProgramData"
  }

    AfterEach {
        Remove-Item $TMP_DIR -Recurse -ErrorAction Ignore
        $env:WINDIR = $ORIGINAL_WINDIR
        $env:PROGRAMDATA = $ORIGINAL_PROGRAMDATA
    }

    It "sets the startup type of sshd to automatic" {
        Mock Set-Service { } -Verifiable  -ParameterFilter { $Name -eq "sshd" -and $StartupType -eq "Automatic" }

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets the startup type of ssh-agent to automatic" {
        Mock Set-Service { } -Verifiable  -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Automatic" }

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets up firewall when ssh not already set up" {
        Mock Get-NetFirewallRule {
            return [ordered]@{
                "Name" = "{3c06039b-ece1-4da3-8ece-255894975894}"
                "DisplayName" = "NTP"
                "Description" = ""
                "DisplayGroup" = ""
                "Group" = ""
                "Enabled" = "True"
                "Profile" = "Any"
                "Platform" = "{}"
                "Direction" = "Outbound"
                "Action" = "Allow"
                "EdgeTraversalPolicy" = "Block"
                "LooseSourceMapping" = "False"
                "LocalOnlyMapping" = "False"
                "Owner" = ""
                "PrimaryStatus" = "OK"
                "Status" = "The rule was parsed successfully from the store. (65536)"
                "EnforcementStatus" = "NotApplicable"
                "PolicyStoreSource" = "PersistentStore"
                "PolicyStoreSourceType" = "Local"
            }
        }

        Mock New-NetFirewallRule { }
        Enable-SSHD -SSHZipFile $FAKE_ZIP
        Assert-MockCalled New-NetFirewallRule -Times 1  -Scope It
    }

    It "doesn't set up firewall when ssh is already set up " {
        Mock Get-NetFirewallRule {
            return [ordered]@{
                "Name" = "{ E02857AB-8EA8-4358-8119-ED7D20DA7712 }"
                "DisplayName" = "SSH"
                "Description" = ""
                "DisplayGroup" = ""
                "Group" = ""
                "Enabled" = "True"
                "Profile" = "Any"
                "Platform" = "{ }"
                "Direction" = "Inbound"
                "Action" = "Allow"
                "EdgeTraversalPolicy" = "Block"
                "LooseSourceMapping" = "False"
                "LocalOnlyMapping" = "False"
                "Owner" = ""
                "PrimaryStatus" = "OK"
                "Status" = "The rule was parsed successfully from the store. (65536)"
                "EnforcementStatus" = "NotApplicable"
                "PolicyStoreSource" = "PersistentStore"
                "PolicyStoreSourceType" = "Local"
            }
        }

        Mock New-NetFirewallRule { }
        Enable-SSHD -SSHZipFile $FAKE_ZIP
        Assert-MockCalled New-NetFirewallRule -Times 0 -Scope It
    }

    It "Generates inf and invokes LGPO if LGPO exists" {
        Mock Run-LGPO -Verifiable -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "Skips LGPO if LGPO.exe not found" {
        rm "$TMP_DIR\Windows\LGPO.exe"

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-MockCalled Run-LGPO -Times 0 -Scope It
    }

    Context "When LGPO executable fails" {
        It "Throws an appropriate error" {
            Mock Run-LGPO { throw "some error" } -Verifiable -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }
            { Enable-SSHD -SSHZipFile $FAKE_ZIP } | Should -Throw "LGPO.exe failed with: some error"
        }
    }

    It "removes existing SSH keys" {
        New-Item -ItemType Directory -Path "$TMP_DIR\ProgramData\ssh" -ErrorAction Ignore
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_1"
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_2"
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_3"
        echo "ignore" > "$TMP_DIR\ProgramData\ssh\not_ssh_host_4"

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        $numHosts = (Get-ChildItem "$TMP_DIR\ProgramData\ssh\").count
        $numHosts | Should -eq 1
    }

    It "creates empty ssh program dir if it doesn't exist" {
        Enable-SSHD -SSHZipFile $FAKE_ZIP
        { Test-Path "$TMP_DIR\ProgramData\ssh" } | Should -eq $True
    }
}

Describe "Extract-LGPO" {
    BeforeEach {
        $guid = $( New-Guid ).Guid
        $TMP_DIR = "$env:TMPDIR/BOSH.SSH.Tests-$guid"

        New-Item -ItemType Directory $TMP_DIR

        $ORIGINAL_WINDIR = $env:WINDIR
        $env:WINDIR = "$TMP_DIR\Windows"
        New-Item -ItemType Directory $env:WINDIR

        Push-Location $TMP_DIR
    }

    AfterEach {
        Pop-Location
        Remove-Item -Recurse -Force $TMP_DIR
        $env:WINDIR = $ORIGINAL_WINDIR
    }

    It "extracts executable from zip" {
        CreateFakeLGPOZip -dir $TMP_DIR -fakeZipPath "$TMP_DIR/LGPO.zip"

        Extract-LGPO

        $lgpoexepath = "$env:WINDIR\LGPO.exe"
        Test-Path -Path $lgpoexepath | Should -Be $true
    }
}

function Get-WuCerts {
}

Describe "Install-WUCerts" {
    It "executes the Get-WUCerts powershell cmdlet" {
        Mock Get-WUCerts { }
        Mock Write-Log { }

        { Install-WUCerts } | Should -Not -Throw

        Assert-MockCalled Get-WUCerts -Times 1 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Successfully retrieved Windows Update certs" }
    }

    It "fails gracefully when Get-WUCerts powershell cmdlet fails" {
        Mock Get-WUCerts { throw "Something went wrong trying to Get-WUCerts" }

        { Install-WUCerts } | Should -Throw "Something went wrong trying to Get-WUCerts"

        Assert-MockCalled Get-WUCerts -Times 1 -Scope It
    }
}

Describe "Create-VersionFile" {
    It "creates a file with the stembuild version" {
        Mock New-VersionFile { }
        Mock Write-Log { }

        { Create-VersionFile -Version '1803.456.17-build.2'} | Should -Not -Throw

        Assert-MockCalled New-VersionFile -Times 1 -Scope It -ParameterFilter {$version -eq '1803.456.17-build.2'}
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Successfully created stemcell version file" }
    }

    It "fails gracefully when New-VersionFile command fails" {
        Mock New-VersionFile { throw "Something went wrong trying to create the version file" }
        Mock Write-Log { }

        { Create-VersionFile -Version '1803.456.17-build.2'} | Should -Throw "Something went wrong trying to create the version file"

        Assert-MockCalled New-VersionFile -Times 1 -Scope It
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Something went wrong trying to create the version file" }
        Assert-MockCalled Write-Log -Times 1 -Scope It -ParameterFilter {$Message -eq "Failed to execute Create-VersionFile command" }
    }

}
