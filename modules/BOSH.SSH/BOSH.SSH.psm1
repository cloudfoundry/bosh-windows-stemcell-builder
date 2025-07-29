function Install-SSHD
{
    if (Get-OSVersion == "windows2019") {
        # Microsoft privided OpenSSH must be installed on Windows 2019
        # => https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell&pivots=windows-server-2019
        $sshPackages = @("OpenSSH.Client", "OpenSSH.Server")
        foreach ($sshPackage in $sshPackages) {
            try {
                $moduleName = (Get-WindowsCapability -Online -Name "$sshPackage*" | ForEach-Object Name)
                Add-WindowsCapability -Online -Name $moduleName
            } catch {
                Write-Output "Error installing $moduleName : $_"
            }
        }
    }

    Edit-DefaultOpenSSHConfig

    Set-Service -Name sshd -StartupType Disabled
    Set-Service -Name ssh-agent -StartupType Disabled
}

function Enable-SSHD
{
    # Remove existing OpenSSH firewall rule and recreate with '-Profile Any' option
    if (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue) {
        "Removing firewall rule: 'OpenSSH-Server-In-TCP'"
        Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
    }
    Write-Output "Creating firewall rule 'OpenSSH-Server-In-TCP'"
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -Profile Any -LocalPort 22

    Set-Service -Name sshd -StartupType Automatic
    Set-Service -Name ssh-agent -StartupType Automatic

    Remove-SSHKeys
}

function Remove-SSHKeys
{
    "Removing any existing host keys"
    Remove-Item -Path "$env:ProgramData\ssh\ssh_host_*" -ErrorAction Ignore
}

function Edit-DefaultOpenSSHConfig
{
    param (
        [string]$ConfigPath = "$env:windir\System32\OpenSSH\sshd_config_default",
        [string]$GeneratedConfigPath = "$env:ProgramData\ssh\sshd_config"
    )

    Copy-Item -Path $ConfigPath -Destination "$ConfigPath.bak"

    $OriginalConfig = Get-Content $ConfigPath
    Write-Output "Original SSH config at $ConfigPath :"
    Write-Output $OriginalConfig

    $ModifiedConfig = $OriginalConfig `
        | ForEach-Object{ $_ -replace ".*Match Group administrators.*", "#$&" } `
        | ForEach-Object{ $_ -replace ".*AllowGroups administrators.*", "#$&" } `
        | ForEach-Object{ $_ -replace ".*AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys.*", "#$&" } `
        | ForEach-Object{ $_ -replace "#RekeyLimit default none", "$&`r`n# Disable cipher to mitigate CVE-2023-48795`r`nCiphers -chacha20-poly1305@openssh.com`r`n" }

    Write-Output "Modified SSH config at $ConfigPath :"
    Write-Output $ModifiedConfig

    Remove-Item -Force $ConfigPath
    Out-File -FilePath $ConfigPath -InputObject $ModifiedConfig -Encoding UTF8

    # We need to make sure that the generated config is cleared, so our above changes are applied when the config
    # is next generated. If this isnt done, then we may have a config from the prior template.
    Remove-Item -Path $GeneratedConfigPath -ErrorAction Ignore
}
