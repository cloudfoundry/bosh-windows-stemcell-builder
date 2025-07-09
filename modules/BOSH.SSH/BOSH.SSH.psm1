function Install-SSHD
{
    $ConfigPath = "$env:windir\System32\OpenSSH\sshd_config_default"
    Edit-DefaultOpenSSHConfig -ConfigPath $ConfigPath

    Set-Service -Name sshd -StartupType Disabled
    Set-Service -Name ssh-agent -StartupType Disabled
}

function Enable-SSHD
{
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }

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
        [string]$ConfigPath = $( Throw "Provide openssh default config path" )
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
}
