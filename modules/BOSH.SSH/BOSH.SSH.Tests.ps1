BeforeAll {
    Remove-Module -Name BOSH.Utils -ErrorAction Ignore
    Import-Module ../BOSH.Utils/BOSH.Utils.psm1

    Remove-Module -Name BOSH.SSH -ErrorAction Ignore
    Import-Module ./BOSH.SSH.psm1

    function Get-FileEncoding
    {
        [CmdletBinding()]
        param (
            [Alias("PSPath")]
            [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
            [String]$Path
        ,
            [Parameter(Mandatory = $False)]
            [System.Text.Encoding]$DefaultEncoding = [System.Text.Encoding]::ASCII
        )

        process {
            [Byte[]]$bom = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 -Path $Path

            $encoding_found = $false

            foreach ($encoding in [System.Text.Encoding]::GetEncodings().GetEncoding())
            {
                $preamble = $encoding.GetPreamble()
                if ($preamble)
                {
                    foreach ($i in 0..$preamble.Length)
                    {
                        if ($preamble[$i] -ne $bom[$i])
                        {
                            break
                        }
                        elseif ($i -eq $preable.Length)
                        {
                            $encoding_found = $encoding
                        }
                    }
                }
            }

            if (!$encoding_found)
            {
                $encoding_found = $DefaultEncoding
            }

            $encoding_found
        }
    }
}

Describe "BOSH.SSH" {
    BeforeEach {
        Mock -ModuleName BOSH.Utils Write-Log { }
        Mock -ModuleName BOSH.SSH Write-Log { }
    }

    Describe "Install-SSHD" {
        BeforeEach {
            Mock Set-Service { } -ModuleName BOSH.SSH
            Mock Edit-DefaultOpenSSHConfig { } -ModuleName BOSH.SSH
        }

        It "sets the startup type of sshd to disabled" {
            Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "sshd" -and $StartupType -eq "Disabled" }

            Install-SSHD

            Assert-VerifiableMock
        }

        It "sets the startup type of ssh-agent to disabled" {
            Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Disabled" }

            Install-SSHD

            Assert-VerifiableMock
        }

        It "calls Edit-DefaultOpenSSHConfig" {
            Mock Edit-DefaultOpenSSHConfig { } -Verifiable -ModuleName BOSH.SSH

            Install-SSHD

            Assert-VerifiableMock
        }
    }

    Describe "Edit-DefaultOpenSSHConfig" {
        BeforeEach {
            Mock -ModuleName BOSH.SSH Set-Service { }

            $guid = $( New-Guid ).Guid
            $TMP_DIR = "$env:TEMP\BOSH.SSH.Tests_Edit-DefaultOpenSSHConfig-$guid"

            $FAKE_WINDIR = "$TMP_DIR\Windows"
            mkdir -p "$FAKE_WINDIR\System32\OpenSSH\"
            New-Item -ItemType Directory -Path "$FAKE_WINDIR\System32\OpenSSH\"  -Force

            $ORIGINAL_WINDIR = $env:WINDIR
            $env:WINDIR = $FAKE_WINDIR

            $GeneratedConfigPath = "$TMP_DIR/sshd_config"
        }

        AfterEach {
            $env:WINDIR = $ORIGINAL_WINDIR
            rmdir $TMP_DIR -Recurse -ErrorAction Ignore
        }

        It "Comments out default configuration for where administrator keys are stored" {
            $ConfigPath = "$TMP_DIR/sshd_config_default"
            $Content = @"
Match Group administrators
AllowGroups administrators "openssh users"
AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
"@
            Out-File -FilePath $ConfigPath -InputObject $Content -Encoding UTF8

            Edit-DefaultOpenSSHConfig -ConfigPath $ConfigPath -GeneratedConfigPath $GeneratedConfigPath

            $ExpectedContent = @"
#Match Group administrators
#AllowGroups administrators "openssh users"
#AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
"@

            ((Get-Content $ConfigPath) -join "`n") | Should -Be $ExpectedContent
        }

        It "Disables the chacha20-poly1305 cipher to mitigate CVE-2023-48795" {
            $ConfigPath = "$TMP_DIR/sshd_config_default"
            $Content = @"
#RekeyLimit default none
"@
            Out-File -FilePath $ConfigPath -InputObject $Content -Encoding UTF8

            Edit-DefaultOpenSSHConfig -ConfigPath $ConfigPath -GeneratedConfigPath $GeneratedConfigPath

            $ExpectedContent = @"
#RekeyLimit default none
# Disable cipher to mitigate CVE-2023-48795
Ciphers -chacha20-poly1305@openssh.com
"@

            ((Get-Content $ConfigPath) -join "`n") | Should -Match $ExpectedContent
        }

        It "sets the file encoding to be UTF8" {
            $ConfigPath = "$TMP_DIR/sshd_config_default"

            Out-File -FilePath $ConfigPath -InputObject "some-fake-content" -Encoding UTF8

            Edit-DefaultOpenSSHConfig -ConfigPath $ConfigPath -GeneratedConfigPath $GeneratedConfigPath

            Get-FileEncoding $ConfigPath | Should -BeLike "System.Text.UTF8Encoding"
        }
    }

    Describe "Enable-SSHD" {
        BeforeEach {
            Mock Set-Service { } -ModuleName BOSH.SSH
            Mock Get-NetFirewallRule { } -ModuleName BOSH.SSH
            Mock New-NetFirewallRule { } -ModuleName BOSH.SSH

            Mock Remove-SSHKeys { } -ModuleName BOSH.SSH
        }

        It "sets the startup type of sshd to automatic" {
            Mock Set-Service { } -ModuleName BOSH.SSH -Verifiable -ParameterFilter {
                $Name -eq "sshd" -and $StartupType -eq "Automatic"
            }

            Enable-SSHD

            Assert-VerifiableMock
        }

        It "sets the startup type of ssh-agent to automatic" {
            Mock -ModuleName BOSH.SSH Set-Service { } -Verifiable -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Automatic" }

            Enable-SSHD

            Assert-VerifiableMock
        }

        It "sets up firewall when ssh not already set up" {
            Mock -ModuleName BOSH.SSH New-NetFirewallRule { } -Verifiable

            Enable-SSHD

            Assert-MockCalled New-NetFirewallRule -ModuleName BOSH.SSH -Times 1
        }

        It "removes the existing SSH firewall rule and recreates it " {
            Mock Get-NetFirewallRule {
                return [ordered]@{
                    "Name" = "OpenSSH-Server-In-TCP"
                }
            } -ModuleName BOSH.SSH

            Mock Remove-NetFirewallRule { } -ModuleName BOSH.SSH -Verifiable -ParameterFilter { $Name -eq "OpenSSH-Server-In-TCP" }
            Mock New-NetFirewallRule { } -ModuleName BOSH.SSH -Verifiable -ParameterFilter {
                $Name -eq "OpenSSH-Server-In-TCP" -and
                        $Enabled -eq "True" -and
                        $Direction -eq "Inbound" -and
                        $Protocol -eq "TCP" -and
                        $Action -eq "Allow" -and
                        $Profile -eq "Any" -and
                        $LocalPort -eq 22
            }
            Enable-SSHD
            Assert-MockCalled Remove-NetFirewallRule -ModuleName BOSH.SSH -Times 1
            Assert-MockCalled New-NetFirewallRule -ModuleName BOSH.SSH -Times 1
        }

        It "invokes Remove-SSHKeys" {
            Mock Remove-SSHKeys { } -ModuleName BOSH.SSH -Verifiable

            Enable-SSHD

            Assert-VerifiableMock
        }
    }

    Describe "Remove-SSHKeys" {
        BeforeEach {
            $guid = $( New-Guid ).Guid
            $TMP_DIR = "$env:TEMP\BOSH.SSH.Tests_Remove-SSHKeys-$guid"

            $ORIGINAL_PROGRAMDATA = $env:ProgramData
            $FAKE_PROGRAMDATA = "$TMP_DIR\ProgramData"

            $env:ProgramData = $FAKE_PROGRAMDATA

            New-Item -ItemType Directory -Path "$FAKE_PROGRAMDATA\ssh" -Force
            Out-File -InputObject "delete" -Encoding UTF8 -FilePath "$FAKE_PROGRAMDATA\ssh\ssh_host_1"
            Out-File -InputObject "delete" -Encoding UTF8 -FilePath "$FAKE_PROGRAMDATA\ssh\ssh_host_2"
            Out-File -InputObject "delete" -Encoding UTF8 -FilePath "$FAKE_PROGRAMDATA\ssh\ssh_host_3"
            Out-File -InputObject "ignore" -Encoding UTF8 -FilePath "$FAKE_PROGRAMDATA\ssh\not_ssh_host_4"
        }

        AfterEach {
            $env:ProgramData = $ORIGINAL_PROGRAMDATA
        }

        It "removes existing SSH keys under 'env:ProgramData\ssh\ssh_host_*'" {
            $initialNumFiles = (Get-ChildItem "$FAKE_PROGRAMDATA\ssh\").Count
            $initialNumFiles | Should -eq 4

            Remove-SSHKeys

            $expectedNumFiles = (Get-ChildItem "$FAKE_PROGRAMDATA\ssh\").Count
            $expectedNumFiles | Should -eq 1
        }
    }
}
