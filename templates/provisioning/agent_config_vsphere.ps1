if(!(Test-Path -Path "C:\bosh" )){
    mkdir "C:\bosh"
}

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
          "Type": "CDROM",
          "FileName": "ENV"
        }
      ]
    }
  }
}
"@
