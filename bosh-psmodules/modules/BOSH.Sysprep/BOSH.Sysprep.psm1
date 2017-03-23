<#
.Synopsis
Sysprep Utilities
.Description
This cmdlet enables running sysprep on a BOSH deployed VM
#>
function Enable-LocalSecurityPolicy {
    Param (
      [string]$LgpoExe = $(Throw "Provide a path for lgpo.exe"),
      [string]$PolicyDestination = "C:\bosh\lgpo"
    )

    Write-Log "Starting LocalSecurityPolicy"

    New-Item -Path "$PolicyDestination" -ItemType Directory -Force
    $policyZipFile = Join-Path $PSScriptRoot "policy-baseline.zip"
    Open-Zip -ZipFile $policyZipFile -OutPath $PolicyDestination
    if (-Not (Test-Path "$PolicyDestination\policy-baseline")) {
	Write-Error "ERROR: could not extract policy-baseline"
    }

    Invoke-Expression "$LgpoExe /g $PolicyDestination\policy-baseline /v 2>&1 > $PolicyDestination\LGPO.log"
    if ($LASTEXITCODE -ne 0) {
	Throw "lgpo.exe exited with $LASTEXITCODE"
    }
    Write-Log "Ending LocalSecurityPolicy"
}
