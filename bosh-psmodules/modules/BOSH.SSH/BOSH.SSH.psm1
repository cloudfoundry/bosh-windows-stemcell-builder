function Install-SSHD {
    param([string]$SSHZipFile= $(Throw "Provide an SSHD zipfile"))

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

    Set-Service sshd -StartupType Disabled
    Set-Service ssh-agent -StartupType Disabled
}
