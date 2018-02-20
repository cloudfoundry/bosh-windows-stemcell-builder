function Install-SSHD {
    param([string]$SSHZipFile= $(Throw "Provide an SSHD zipfile"))

    New-Item "C:\Program Files\SSHTemp" -Type Directory -Force
    Open-Zip -ZipFile $SSHZipFile -OutPath "C:\Program Files\SSHTemp"
    Move-Item -Force "C:\Program Files\SSHTemp\OpenSSH-Win64" "C:\Program Files\OpenSSH"
    Remove-Item -Force "C:\Program Files\SSHTemp"

    # Remove users from 'OpenSSH' before installing.  The install process
    # will add back permissions for the NT SERVICE\SSHD user for some files
    Protect-Dir -path "C:\Program Files\OpenSSH"

    Push-Location "C:\Program Files\OpenSSH"
        powershell -ExecutionPolicy Bypass -File install-sshd.ps1
    Pop-Location

# Grant NT SERVICE\SSHD user access to .EXEs and the .DLL in OpenSSH
    $FileNames=@(
        "libcrypto-41.dll",
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
    cacls.exe "C:\Program Files\OpenSSH" /E /P "NT SERVICE\SSHD:R"
    foreach ($name in $FileNames) {
        $path = Join-Path "C:\Program Files\OpenSSH" $name
        cacls.exe $path /E /P "NT SERVICE\SSHD:R"
    }

    Set-Service sshd -StartupType Disabled
    Set-Service ssh-agent -StartupType Disabled
}
