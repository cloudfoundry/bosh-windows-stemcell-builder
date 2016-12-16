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

function Set-Restricted-Acl
{
    param([string]$path)

    $acl = Get-Acl $path
    $acl.Access | %{$acl.RemoveAccessRuleAll($_)}
    Set-Acl $path $acl

    Get-ChildItem $path -recurse -Force | % {
        $acl = Get-Acl $_.FullName;
        $acl.Access | %{$acl.RemoveAccessRuleAll($_)}
        Set-Acl $_.FullName $acl
    }
}


# Add utilities to current path.
$env:PATH="${env:PATH};C:\var\vcap\bosh\bin"

# Add utilities to system path (does not apply to current shell).
Setx $env:PATH "${env:PATH};C:\var\vcap\bosh\bin" /m

New-Item -Path "C:\bosh" -ItemType "directory" -Force
Set-Restricted-Acl "C:\bosh"

New-Item -Path "C:\var\vcap\bosh\bin" -ItemType "directory" -Force
New-Item -Path "C:\var\vcap\bosh\log" -ItemType "directory" -Force
Set-Restricted-Acl "C:\var\vcap"

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

Exit 0
