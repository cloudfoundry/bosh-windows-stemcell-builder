if(!(Test-Path -Path "C:\bosh" )){
    mkdir "C:\bosh"
}

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
