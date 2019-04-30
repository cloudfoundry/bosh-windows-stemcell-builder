function Install-SSHD
{
    param (
        [string]$SSHZipFile = $( Throw "Provide an SSHD zipfile" )
    )

    New-Item "$env:PROGRAMFILES\SSHTemp" -Type Directory -Force
    Open-Zip -ZipFile $SSHZipFile -OutPath "$env:PROGRAMFILES\SSHTemp"
    Move-Item -Force "$env:PROGRAMFILES\SSHTemp\OpenSSH-Win64" "$env:PROGRAMFILES\OpenSSH"
    Remove-Item -Force "$env:PROGRAMFILES\SSHTemp"

    # Remove users from 'OpenSSH' before installing.  The install process
    # will add back permissions for the NT AUTHORITY\Authenticated Users for some files
    Protect-Dir -path "$env:PROGRAMFILES\OpenSSH"

    Push-Location "$env:PROGRAMFILES\OpenSSH"
    powershell -ExecutionPolicy Bypass -File install-sshd.ps1
    Pop-Location


    $SSHDir = "$env:PROGRAMFILES\OpenSSH"

    if ((Get-NetFirewallRule | where { $_.DisplayName -ieq 'SSH' }) -eq $null)
    {
        "Creating firewall rule for SSH"
        New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
    }
    else
    {
        "Firewall rule for SSH already exists"
    }

    $SSHDir = "$env:PROGRAMFILES\OpenSSH"

    $InfFilePath = "$env:WINDIR\Temp\enable-ssh.inf"

    $InfFileContents = @'
[Unicode]
Unicode=yes
[Version]
signature=$CHICAGO$
Revision=1
[Registry Values]
[System Access]
[Privilege Rights]
SeDenyNetworkLogonRight=*S-1-5-32-546
SeAssignPrimaryTokenPrivilege=*S-1-5-19,*S-1-5-20,*S-1-5-80-3847866527-469524349-687026318-516638107-1125189541
'@
    $LGPOPath = "$env:WINDIR\LGPO.exe"
    if (Test-Path $LGPOPath)
    {
        Out-File -FilePath $InfFilePath -Encoding unicode -InputObject $InfFileContents -Force
        Try
        {
            Run-LGPO -LGPOPath $LGPOPath -InfFilePath $InfFilePath
        }
        Catch
        {
            throw "LGPO.exe failed with: $_.Exception.Message"
        }
    }
    else
    {
        "Did not find $LGPOPath. Assuming existing security policies are sufficient to support ssh."
    }
    #    # Grant NT AUTHORITY\Authenticated Users access to .EXEs and the .DLL in OpenSSH
    $FileNames = @(
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
    Invoke-CACL -FileNames $FileNames
    Remove-SSHKeys

    Set-Service -Name sshd -StartupType Automatic #TODO: test
    # ssh-agent is not the same as ssh-agent in *nix openssh
    Set-Service -Name ssh-agent -StartupType Automatic #TODO: test
}

function Remove-SSHKeys
{
    $SSHDir = "C:\Program Files\OpenSSH"

    Push-Location $SSHDir
    New-Item -ItemType Directory -Path "$env:ProgramData\ssh" -ErrorAction Ignore

    "Removing any existing host keys"
    Remove-Item -Path "$env:ProgramData\ssh\ssh_host_*" -ErrorAction Ignore
    Pop-Location
}

function Invoke-CACL
{
    param (
        [string[]] $FileNames = $( Throw "Files not provided" )
    )

    foreach ($name in $FileNames)
    {
        $path = Join-Path "$env:PROGRAMFILES\OpenSSH" $name
        cacls.exe $Path /E /P "NT AUTHORITY\Authenticated Users:R"
    }
}

function Run-LGPO
{
    param (
        [string]$LGPOPath = $( Throw "Provide LGPO path" ),
        [string]$InfFilePath = $( Throw "Provide Inf file path" )
    )
    & $LGPOPath /s $InfFilePath
}
