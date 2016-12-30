$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function Get-CurrentLineNumber {
    $MyInvocation.ScriptLineNumber
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

    Remove-Item -Path $zipfile -Force
}

function setup-acl {

    param([string]$folder)

    cacls.exe $folder /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with $LASTEXITCODE"
    }
    cacls.exe $folder /T /E /G Administrator:F
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with $LASTEXITCODE"
    }

    $acl = Get-ACL -Path $folder
    $acl.SetAccessRuleProtection($True, $True)
    Set-Acl -Path $folder -AclObject $acl
}

# Add utilities to current path.
$env:PATH="${env:PATH};C:\var\vcap\bosh\bin"

# Add utilities to system path (does not apply to current shell).
Setx $env:PATH "${env:PATH};C:\var\vcap\bosh\bin" /m

New-Item -Path "C:\bosh" -ItemType "directory" -Force
# Remove permissions for C:\bosh directories.
setup-acl "C:\bosh"

New-Item -Path "C:\var\vcap\bosh\bin" -ItemType "directory" -Force
New-Item -Path "C:\var\vcap\bosh\log" -ItemType "directory" -Force
# Remove permissions for C:\var
setup-acl "C:\var"

Unzip "C:\bosh\agent_deps.zip" "C:\var\vcap\bosh\bin\"
Invoke-WebRequest "${ENV:AGENT_ZIP_URL}" -Verbose -OutFile "C:\bosh\agent.zip"
Unzip "C:\bosh\agent.zip" "C:\bosh\"
Move-Item "C:\bosh\pipe.exe" "C:\var\vcap\bosh\bin\pipe.exe"

$OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
$AddedFolder='C:\var\vcap\bosh\bin'
$NewPath=$OldPath+';'+$AddedFolder
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath

C:\bosh\service_wrapper.exe install
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error installing BOSH service wrapper"
}


# Remove permissions for C:\windows\panther directories.
setup-acl "C:\Windows\Panther"
setup-acl "C:\Windows\Temp"

Exit 0
