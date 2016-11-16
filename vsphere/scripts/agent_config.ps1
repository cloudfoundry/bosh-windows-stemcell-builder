$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

New-Item -Path "C:\bosh" -ItemType "directory" -Force

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
