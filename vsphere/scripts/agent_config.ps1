$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function setup-acl {

    param([string]$folder)

    cacls.exe $folder /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with {0}" -f $LASTEXITCODE
    }
    cacls.exe $folder /T /E /G Administrator:F
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with {0}" -f $LASTEXITCODE
    }
}

New-Item -Path "C:\bosh" -ItemType "directory" -Force
setup-acl "C:\bosh"

New-Item -ItemType "file" -path "C:\bosh\agent.json" -Value @"
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "scsi"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "CDROM",
          "FileName": "ENV"
        }
      ]
    }
  }
}
"@
