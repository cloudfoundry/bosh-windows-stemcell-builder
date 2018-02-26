<#
.Synopsis
    Install BOSH Agent
.Description
    This cmdlet installs BOSH Agent
#>
$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function Install-Agent {
    Param(
        [string]$IaaS = $(Throw "Provide the IaaS of your VM"),
        [string]$agentZipPath = $(Throw "Provide the path of your agent.zip")
    )

    Write-Log "Install-Agent: Started"

    Copy-Agent -InstallDir "C:\" -agentZipPath $agentZipPath
    Protect-Dir -Path "C:\bosh"
    Protect-Dir -Path "C:\var"
    Write-AgentConfig -BoshDir "C:\bosh" -IaaS $IaaS
    Set-Path "C:\var\vcap\bosh\bin"
    Install-AgentService
    Protect-Dir -Path "C:\Windows\Panther" -disableInheritance $False
    Write-Log "Install-Agent: Finished"
}

function Copy-Agent {
    Param(
      [string]$installDir = $(Throw "Provide a directory to install the BOSH agent"),
      [string]$agentZipPath = $(Throw "Provide the path to the BOSH agent zipfile")
    )

    Write-Log "Copy-Agent InstallDir=${installDir} Zip=${agentZipPath}"

    $boshDir = (Join-Path $installDir "bosh")
    if (Test-Path $boshDir) {
        Write-Log "Copy-Agent removing existing BOSH dir: ${boshDir}"
        Remove-Item -Path $boshDir -Recurse -Force
    }
    New-Item -Path $boshDir -ItemType Directory -Force

    $varDir = (Join-Path $installDir "var")
    if (Test-Path $varDir) {
        Write-Log "Copy-Agent removing existing VAR dir: ${varDir}"
        Remove-Item -Path $varDir -Recurse -Force
    }
    $vcapDir = (Join-Path $installDir (Join-Path "var" (Join-Path "vcap" "bosh")))
    New-Item -Path (Join-Path $vcapDir "log") -ItemType Directory -Force

    $depsDir = (Join-Path $vcapDir "bin")
    if (Test-Path $depsDir) {
        Write-Log "Copy-Agent removing existing Deps dir: ${depsDir}"
        Remove-Item -Path $depsDir -Recurse -Force
    }
    New-Item -Path $depsDir -ItemType Directory -Force

    Open-Zip $agentZipPath $boshDir
    Move-Item (Join-Path $boshDir (Join-Path "deps" "*")) $depsDir
    Remove-Item -Path (Join-Path $boshDir "deps") -Force
}


function Write-AgentConfig {
    Param(
      [string]$boshDir = $(Throw "Provide a directory to install the BOSH agent config"),
      [string]$IaaS = $(Throw "Provide an IaaS for configuration")
    )

    if (-Not (Test-Path $boshDir -PathType Container)) {
        Throw "Error: $($boshDir) does not exist"
    }

    $awsConfig = @"
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
          "InstanceIDPath": "/latest/meta-data/instance-id/"
        }
      ],
      "UseRegistry": true
    }
  }
}
"@
    $azureConfig = @"
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
          "MetaDataPath": "C:/AzureData/CustomData.bin",
          "UserDataPath": "C:/AzureData/CustomData.bin",
          "SettingsPath": "C:/AzureData/CustomData.bin"
        }
      ],
      "UseServerName": false,
      "UseRegistry": true
    }
  }
}
"@
    $gcpConfig = @"
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true,
      "DevicePathResolutionType": "virtio",
      "VirtioDevicePrefix": "google"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "InstanceMetadata",
          "URI": "http://169.254.169.254",
          "SettingsPath": "/computeMetadata/v1/instance/attributes/bosh_settings",
          "Headers": {
            "Metadata-Flavor": "Google"
          }
        }
      ],
      "UseServerName": true,
      "UseRegistry": false
    }
  }
}
"@
    $openstackConfig = @"
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
      "UseRegistry": true,
      "UseServerName": true
    }
  }
}
"@
    $vsphereConfig = @"
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

    if ($IaaS -eq 'aws') {
        Write-Log "Agent Config: ${awsConfig}"
        New-Item -ItemType file -path (Join-Path $boshDir "agent.json") -Value $awsConfig
    } elseif ($IaaS -eq 'azure') {
        Write-Log "Agent Config: ${azureConfig}"
        New-Item -ItemType file -path (Join-Path $boshDir "agent.json") -Value $azureConfig
    } elseif ($IaaS -eq 'vsphere') {
        Write-Log "Agent Config: ${vsphereConfig}"
        New-Item -ItemType file -path (Join-Path $boshDir "agent.json") -Value $vsphereConfig
    } elseif ($IaaS -eq 'gcp') {
        Write-Log "Agent Config: ${gcpConfig}"
        New-Item -ItemType file -path (Join-Path $boshDir "agent.json") -Value $gcpConfig
    } elseif ($IaaS -eq 'openstack') {
        Write-Log "Agent Config: ${openstackConfig}"
        New-Item -ItemType file -path (Join-Path $boshDir "agent.json") -Value $openstackConfig
    } else {
        Throw "IaaS $($IaaS) is not supported"
    }

}

function Set-Path {
  Param(
      [string]$Path= $(Throw "Error: Provide a directory to add to the path")
    )
    Write-Log "Set-Path: ${Path} to path"
    Setx PATH "${env:PATH};${Path}" /m
}

function Install-AgentService {
    Write-Log "Updating services timeout from 30s to 60s"
    $parentRegistryPath = "HKLM:\SYSTEM\CurrentControlSetup"
    $registryPath = "HKLM:\SYSTEM\CurrentControlSetup\Control"
    $name = "ServicesPipeTimeout"
    $value = 60000

    If (-NOT (Test-Path $parentRegistryPath)) {
      New-Item $parentRegistryPath | Out-Null
    }

    If (-NOT (Test-Path $registryPath)) {
      New-Item $registryPath | Out-Null
    }

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    Write-Log "Install-AgentService: Installing BOSH Agent"
    Start-Process -FilePath "C:\bosh\service_wrapper.exe" -ArgumentList "install" -NoNewWindow -Wait
}

