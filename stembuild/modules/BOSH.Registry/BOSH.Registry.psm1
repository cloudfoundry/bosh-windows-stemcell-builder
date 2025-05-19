function Invoke-LGPO-Build-Pol-From-Text {
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $LGPOTextReadPath,

        [Parameter(Mandatory=$True)]
        [String]
        $RegistryPolWritePath
    )
    process {
        LGPO.exe /r $LGPOTextReadPath /w $RegistryPolWritePath
        return $LASTEXITCODE
    }
}

function Invoke-LGPO-Apply-Policies {
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $RegistryPolPath
    )
    process {
        LGPO.exe /g $RegistryPolPath
        return $LASTEXITCODE
    }
}

function Set-InternetExplorerRegistries {
    <#
    .SYNOPSIS
        Apply BOSH Windows Stemcell registry settings related to internet explorer
    .DESCRIPTION
        Apply Internet Explorer registry settings taken from Microsoft's baseline security analysis tool
    .INPUTS
        None. You can't pipe anything in to this command
    .OUTPUTS
        Set-InternetExplorerRegistries will return any failure output
    #>

    [CmdletBinding()]

    param()

    process {
        Write-Log "Starting Internet Explorer Registry Changes"
        $IePolicyPath = Join-Path $PSScriptRoot "data\IE-Policies"

        $MachineDir="$IePolicyPath\DomainSysvol\GPO\Machine"

        New-Item -ItemType Directory -Path $MachineDir -Force -ErrorAction "Stop"
        $machinePolicyExitCode = Invoke-LGPO-Build-Pol-From-Text -LGPOTextReadPath "$IePolicyPath\machine.txt" -RegistryPolWritePath "$MachineDir\registry.pol"
        if ($machinePolicyExitCode -ne 0) {
            Throw "Generating IE policy: Machine"
        }

        $UserDir="$IePolicyPath\DomainSysvol\GPO\User"
        New-Item -ItemType Directory -Path $UserDir -Force -ErrorAction "Stop"
        $userPolicyExitCode = Invoke-LGPO-Build-Pol-From-Text -LGPOTextReadPath "$IePolicyPath\user.txt" -RegistryPolWritePath "$UserDir\registry.pol"
        if ($userPolicyExitCode -ne 0) {
            Throw "Generating IE policy: User"
        }

        # Apply policies
        $policyApplicationExitCode = Invoke-LGPO-Apply-Policies -RegistryPolPath $IePolicyPath
        if ($policyApplicationExitCode -ne 0) {
            Throw "Error Applying IE policy: $IePolicyPath"
        }
    }
}