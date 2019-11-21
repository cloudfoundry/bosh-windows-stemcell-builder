Remove-Module -Name BOSH.SSH -ErrorAction Ignore
Import-Module ./BOSH.SSH.psm1


function CreateFakeOpenSSHZip
{
    param([string]$dir, [string]$installScriptSpyStatus, [string]$fakeZipPath)

    mkdir "$dir\OpenSSH-Win64"
    $installSpyBehavior = "echo installed > $installScriptSpyStatus"
    echo $installSpyBehavior > "$dir\OpenSSH-Win64\install-sshd.ps1"
    echo "fake sshd" > "$dir\OpenSSH-Win64\sshd.exe"
    echo "fake config" > "$dir\OpenSSH-Win64\sshd_config_default"

    Compress-Archive -Force -Path "$dir\OpenSSH-Win64" -DestinationPath $fakeZipPath
}

Describe "Enable-SSHD" {
    BeforeEach {
        Mock Set-Service { } -ModuleName BOSH.SSH
        Mock Run-LGPO { } -ModuleName BOSH.SSH

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
        rmdir $TMP_DIR -Recurse -ErrorAction Ignore
        $env:WINDIR = $ORIGINAL_WINDIR
        $env:PROGRAMDATA = $ORIGINAL_PROGRAMDATA
    }

    It "sets the startup type of sshd to automatic" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "sshd" -and $StartupType -eq "Automatic" }

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets the startup type of ssh-agent to automatic" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Automatic" }

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
        } -ModuleName BOSH.SSH

        Mock New-NetFirewallRule { } -ModuleName BOSH.SSH
        Enable-SSHD -SSHZipFile $FAKE_ZIP
        Assert-MockCalled New-NetFirewallRule -Times 1 -ModuleName BOSH.SSH -Scope It
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
        } -ModuleName BOSH.SSH

        Mock New-NetFirewallRule { } -ModuleName BOSH.SSH
        Enable-SSHD -SSHZipFile $FAKE_ZIP
        Assert-MockCalled New-NetFirewallRule -Times 0 -ModuleName BOSH.SSH -Scope It
    }

    It "Generates inf and invokes LGPO if LGPO exists" {
        Mock Run-LGPO -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "Skips LGPO if LGPO.exe not found" {
        rm "$TMP_DIR\Windows\LGPO.exe"

        Enable-SSHD -SSHZipFile $FAKE_ZIP

        Assert-MockCalled Run-LGPO -Times 0 -ModuleName BOSH.SSH -Scope It
    }

    Context "When LGPO executable fails" {
        It "Throws an appropriate error" {
            Mock Run-LGPO { throw "some error" } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }
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

Describe "Install-SSHD" {
    BeforeEach {
        Mock Set-Service { } -ModuleName BOSH.SSH
        Mock Protect-Dir { } -ModuleName BOSH.SSH
        Mock Invoke-CACL { } -ModuleName BOSH.SSH
        Mock Write-Log { } -ModuleName BOSH.Utils

        $guid = $( New-Guid ).Guid
        $TMP_DIR = "$env:TEMP\BOSH.SSH.Tests-$guid"

        mkdir -p "$TMP_DIR\Windows\Temp"
        mkdir -p "$TMP_DIR\ProgramData"

        $FAKE_ZIP = "$TMP_DIR\OpenSSH-TestFake.zip"
        $INSTALL_SCRIPT_SPY_STATUS = "$TMP_DIR\install-script-status"

        CreateFakeOpenSSHZip -dir $TMP_DIR -installScriptSpyStatus $INSTALL_SCRIPT_SPY_STATUS -fakeZipPath $FAKE_ZIP

        $ORIGINAL_PROGRAMFILES = $env:PROGRAMFILES
        $env:PROGRAMFILES = "$TMP_DIR\ProgramFiles"
    }

    AfterEach {
        rmdir $TMP_DIR -Recurse -ErrorAction Ignore
        $env:PROGRAMFILES = $ORIGINAL_PROGRAMFILES
    }

    It "extracts OpenSSH to Program Files" {
        Install-SSHD -SSHZipFile $FAKE_ZIP

        Get-Item $env:PROGRAMFILES\OpenSSH | Should -Exist
        Get-Item $env:PROGRAMFILES\OpenSSH\sshd.exe | Should -Exist
    }

    It "runs the install-sshd script" {
        Install-SSHD -SSHZipFile $FAKE_ZIP

        "$INSTALL_SCRIPT_SPY_STATUS" | Should -FileContentMatchExactly 'installed'
    }

    It "calls Protect-Dir to lock down permissions" {
        Mock Protect-Dir { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $path -eq "$env:PROGRAMFILES\OpenSSH" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "calls Invoke-CACL with expected files" {
        Mock Invoke-CACL { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter {
            @(
            "libcrypto.dll",
            "scp.exe",
            "sftp-server.exe",
            "sftp.exe",
            "ssh-add.exe",
            "ssh-agent.exe",
            "ssh-keygen.exe",
            "ssh-keyscan.exe",
            "ssh-shellhost.exe",
            "ssh.exe",
            "sshd.exe"
            )
        }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets the startup type of sshd to disabled" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "sshd" -and $StartupType -eq "Disabled" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets the startup type of ssh-agent to disabled" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Disabled" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "modifies the openssh configuration to remove default admin key location while maintaining UTF-8 encoding" {
        Mock Get-Content { @"
Match Group administrators
AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
"@ } -ModuleName BOSH.SSH -ParameterFilter { $Path -like "*sshd_config_default" }

        Install-SSHD -SSHZipFile $FAKE_ZIP
        Get-Content $env:PROGRAMFILES\OpenSSH\sshd_config_default | Out-String | Should -BeLike "#*#*"
        file.exe $env:PROGRAMFILES\OpenSSH\sshd_config_default | Should -BeLike "*UTF-8*"
    }

}

Describe "Modify-DefaultOpenSSHConfig"{
    It "Comments out default configuration for where administrator keys are stored" {

        Mock Get-Content {
@"
Match Group administrators
AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
"@
        } -ModuleName BOSH.SSH

        $result = Modify-DefaultOpenSSHConfig -ConfigPath "some/path/sshd_config_default"

        Assert-MockCalled Get-Content -Times 1 -ModuleName BOSH.SSH -Scope It -ParameterFilter { $Path -like "*sshd_config_default" }
        $result | Should -BeLike "#*#*"
    }

}
