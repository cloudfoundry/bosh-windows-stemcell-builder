Remove-Module -Name BOSH.SSH -ErrorAction Ignore
Import-Module ./BOSH.SSH.psm1


function CreateFakeOpenSSHZip
{
    param([string]$dir, [string]$installScriptSpyStatus, [string]$fakeZipPath)

    mkdir "$dir\OpenSSH-Win64"
    $installSpyBehavior = "echo installed > $installScriptSpyStatus"
    echo $installSpyBehavior > "$dir\OpenSSH-Win64\install-sshd.ps1"
    echo "fake sshd" > "$dir\OpenSSH-Win64\sshd.exe"

    Compress-Archive -Force -Path "$dir\OpenSSH-Win64" -DestinationPath $fakeZipPath
}

Describe "Install-SSHD" {
    BeforeEach {
        Mock Protect-Dir { } -ModuleName BOSH.SSH
        Mock Set-Service { } -ModuleName BOSH.SSH
        Mock Invoke-CACL { } -ModuleName BOSH.SSH
        Mock Run-LGPO { } -ModuleName BOSH.SSH

        $guid = $( New-Guid ).Guid
        $TMP_DIR = "$env:TEMP\BOSH.SSH.Tests-$guid"

        mkdir -p "$TMP_DIR\Windows\Temp"
        mkdir -p "$TMP_DIR\ProgramData"

        echo "fake LGPO" > "$TMP_DIR\Windows\LGPO.exe"

        $FAKE_ZIP = "$TMP_DIR\OpenSSH-TestFake.zip"
        $INSTALL_SCRIPT_SPY_STATUS = "$TMP_DIR\install-script-status"

        CreateFakeOpenSSHZip -dir $TMP_DIR -installScriptSpyStatus $INSTALL_SCRIPT_SPY_STATUS -fakeZipPath $FAKE_ZIP

        $ORIGINAL_PROGRAMFILES = $env:PROGRAMFILES
        $ORIGINAL_PROGRAMDATA = $env:ProgramData
        $ORIGINAL_WINDIR = $env:WINDIR
        $env:PROGRAMFILES = "$TMP_DIR\ProgramFiles"
        $env:PROGRAMDATA = "$TMP_DIR\ProgramData"
        $env:WINDIR = "$TMP_DIR\Windows"
    }

    AfterEach {
        rmdir $TMP_DIR -Recurse -ErrorAction Ignore
        $env:PROGRAMFILES = $ORIGINAL_PROGRAMFILES
        $env:PROGRAMDATA = $ORIGINAL_PROGRAMDATA
        $env:WINDIR = $ORIGINAL_WINDIR
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

    It "sets the startup type of sshd to automatic" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "sshd" -and $StartupType -eq "Automatic" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "sets the startup type of ssh-agent to automatic" {
        Mock Set-Service { } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $Name -eq "ssh-agent" -and $StartupType -eq "Automatic" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

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
        Install-SSHD -SSHZipFile $FAKE_ZIP
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
        Install-SSHD -SSHZipFile $FAKE_ZIP
        Assert-MockCalled New-NetFirewallRule -Times 0 -ModuleName BOSH.SSH -Scope It
    }

    It "Generates inf and invokes LGPO if LGPO exists" {
        Mock Run-LGPO -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-VerifiableMock
    }

    It "Skips LGPO if LGPO.exe not found" {
        rm "$TMP_DIR\Windows\LGPO.exe"

        Install-SSHD -SSHZipFile $FAKE_ZIP

        Assert-MockCalled Run-LGPO -Times 0 -ModuleName BOSH.SSH -Scope It
    }

    Context "When LGPO executable fails" {
        It "Throws an appropriate error" {
            Mock Run-LGPO { throw "some error" } -Verifiable -ModuleName BOSH.SSH -ParameterFilter { $LGPOPath -eq "$TMP_DIR\Windows\LGPO.exe" -and $InfFilePath -eq "$TMP_DIR\Windows\Temp\enable-ssh.inf" }
            { Install-SSHD -SSHZipFile $FAKE_ZIP } | Should -Throw "LGPO.exe failed with: some error"
        }
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

    It "removes existing SSH keys" {
        New-Item -ItemType Directory -Path "$TMP_DIR\ProgramData\ssh" -ErrorAction Ignore
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_1"
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_2"
        echo "delete" > "$TMP_DIR\ProgramData\ssh\ssh_host_3"
        echo "ignore" > "$TMP_DIR\ProgramData\ssh\not_ssh_host_4"

        Install-SSHD -SSHZipFile $FAKE_ZIP

        $numHosts = (Get-ChildItem "$TMP_DIR\ProgramData\ssh\").count
        $numHosts | Should -eq 1
    }

    It "creates empty ssh program dir if it doesn't exist" {
        Install-SSHD -SSHZipFile $FAKE_ZIP
        { Test-Path "$TMP_DIR\ProgramData\ssh" } | Should -eq $True
    }
}