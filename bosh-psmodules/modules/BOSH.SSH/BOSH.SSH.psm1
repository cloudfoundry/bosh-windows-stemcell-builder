function Install-SSHD
{
    param ([string]$SSHZipFile = $( Throw "Provide an SSHD zipfile" ))

    New-Item "C:\Program Files\SSHTemp" -Type Directory -Force
    Open-Zip -ZipFile $SSHZipFile -OutPath "C:\Program Files\SSHTemp"
    Move-Item -Force "C:\Program Files\SSHTemp\OpenSSH-Win64" "C:\Program Files\OpenSSH"
    Remove-Item -Force "C:\Program Files\SSHTemp"

    # Remove users from 'OpenSSH' before installing.  The install process
    # will add back permissions for the NT AUTHORITY\Authenticated Users for some files
    Protect-Dir -path "C:\Program Files\OpenSSH"

    Push-Location "C:\Program Files\OpenSSH"
    powershell -ExecutionPolicy Bypass -File install-sshd.ps1
    Pop-Location


    $SSHDir="C:\Program Files\OpenSSH"

    if ((Get-NetFirewallRule | where { $_.DisplayName -eq 'SSH' }) -eq $null)
    {
        "Creating firewall rule for SSH"
        New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH
    }
    else
    {
        "Firewall rule for SSH already exists"
    }


    $SSHDir="C:\Program Files\OpenSSH"
    $LGPOPath="C:\Windows\LGPO.exe"
    $InfFilePath="C:\Windows\Temp\enable-ssh.inf"

    $InfFileContents=@'
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

    $LGPOPath="C:\Windows\LGPO.exe"
    if (Test-Path $LGPOPath) {
        "Found $LGPOPath. Modifying security policies to support ssh."
        Out-File -FilePath $InfFilePath -Encoding unicode -InputObject $InfFileContents -Force
        & $LGPOPath /s $InfFilePath
        if ($LASTEXITCODE -ne 0) {
            Write-Error "LGPO.exe exited with non-zero code: ${LASTEXITCODE}"
            Exit $LASTEXITCODE
        }
    } else {
        "Did not find $LGPOPath. Assuming existing security policies are sufficient to support ssh."
    }

    # Grant NT AUTHORITY\Authenticated Users access to .EXEs and the .DLL in OpenSSH
    $FileNames=@(
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
    foreach ($name in $FileNames) {
        $path = Join-Path "C:\Program Files\OpenSSH" $name
        cacls.exe $path /E /P "NT AUTHORITY\Authenticated Users:R"
    }

    Remove-SSHKeys

    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic

}

function Remove-SSHKeys
{
    $SSHDir="C:\Program Files\OpenSSH"

    Push-Location $SSHDir
    New-Item -ItemType Directory -Path "$env:ProgramData\ssh" -ErrorAction Ignore
    cat "$env:ProgramData\ssh\ssh_host_*"

    "Removing any existing host keys"
    Remove-Item -Path "$env:ProgramData\ssh\ssh_host_*" -ErrorAction Ignore
    Pop-Location

}
