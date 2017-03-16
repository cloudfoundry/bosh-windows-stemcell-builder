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
    Set-Path
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
    New-Item -Path $boshDir -ItemType Directory -Force

    $vcapDir = (Join-Path $installDir (Join-Path "var" (Join-Path "vcap" "bosh")))
    $depsDir = (Join-Path $vcapDir "bin")
    New-Item -Path $depsDir -ItemType Directory -Force
    New-Item -Path (Join-Path $vcapDir "log") -ItemType Directory -Force

    Open-Zip $agentZipPath $boshDir
    Move-Item (Join-Path $boshDir (Join-Path "deps" "*")) $depsDir
    Remove-Item -Path (Join-Path $boshDir "deps") -Force
}

function Protect-Dir {
    Param(
        [string]$path = $(Throw "Provide a directory to set ACL on"),
        [bool]$disableInheritance=$True
    )

    Write-Log "Protect-Dir: Remove BUILTIN\Users"
    cacls.exe $path /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Remove BUILTIN\IIS_IUSRS"
    cacls.exe $path /T /E /R "BUILTIN\IIS_IUSRS"
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    Write-Log "Protect-Dir: Grant Administrator"
    cacls.exe $path /T /E /G Administrator:F
    if ($LASTEXITCODE -ne 0) {
        Throw "Error setting ACL for $path exited with $LASTEXITCODE"
    }

    if ($disableInheritance) {
        Write-Log "Protect-Dir: Disable Inheritance"
        $acl = Get-ACL -Path $path
        $acl.SetAccessRuleProtection($True, $True)
        Set-Acl -Path $path -AclObject $acl
    }
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
          "InstanceIDPath": "/latest/meta-data/instance-id/",
          "SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key/"
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
          "MetaDataPath": "",
          "UserDataPath": "C:/AzureData/CustomData.bin",
          "SettingsPath": "C:/AzureData/CustomData.bin"
        }
      ],
      "UseServerName": true,
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
    } else {
        Throw "IaaS $($IaaS) is not supported"
    }

}

function Set-Path {
    Write-Log "Set-Path: C:\\var\\vcap\\bosh\\bin to path"
    Setx PATH "${env:PATH};C:\var\vcap\bosh\bin" /m
}

function Install-AgentService {
    Write-Log "Install-AgentService: Installing BOSH Agent"
    Start-Process -FilePath "C:\bosh\service_wrapper.exe" -ArgumentList "install" -NoNewWindow -Wait
}

