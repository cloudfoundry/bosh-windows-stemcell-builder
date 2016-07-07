mkdir "C:\bosh"
mkdir "C:\var\vcap\bosh\bin"
mkdir "C:\var\vcap\bosh\log"

# Add utilities to current path.
$env:PATH="${env:PATH};C:\var\vcap\bosh\bin"

# Add utilities to system path (does not apply to current shell).
Setx $env:PATH "${env:PATH};C:\var\vcap\bosh\bin" /m

Add-Type -AssemblyName System.IO.Compression.FileSystem
  function Unzip
  {
      param([string]$zipfile, [string]$outpath)

      [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

      rm $zipfile
  }

Invoke-WebRequest "${ENV:AGENT_DEPS_ZIP_URL}" -Verbose -OutFile "C:\bosh\agent_deps.zip"
Unzip "C:\bosh\agent_deps.zip" "C:\var\vcap\bosh\bin\"

Invoke-WebRequest "${ENV:AGENT_ZIP_URL}" -Verbose -OutFile "C:\bosh\agent.zip"
Unzip "C:\bosh\agent.zip" "C:\bosh\"

$OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
$AddedFolder='C:\bosh'
$NewPath=$OldPath+';'+$AddedFolder
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath

New-Item -ItemType file -path "C:\bosh\agent.json" -Value @"
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254",
          "UserDataPath": "/latest/user-data/",
          "InstanceIDPath": "/latest/meta-data/instance-id/",
          "SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key/"
        }
      ],
      "UseRegistry": true
    }
  }
}
"@

# BOSH Agent Service Wrapper
C:\bosh\service_wrapper.exe install
