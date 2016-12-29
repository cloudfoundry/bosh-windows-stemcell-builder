$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

New-Item -Path "C:\bosh" -ItemType "directory" -Force

New-Item -ItemType file -path "C:\bosh\agent.json" -Value @"
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
          "Type": "File",
          "MetaDataPath": "",
          "UserDataPath": "/var/lib/waagent/CustomData",
          "SettingsPath": "/var/lib/waagent/CustomData"
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
"@

Exit 0
