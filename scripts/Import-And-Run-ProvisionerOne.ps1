$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Write-Host "HELLOOO"
# .\install-bosh-psmodules.ps1


# Move the content of install-bosh-psmodules into here
# directly, rather than calling that script.