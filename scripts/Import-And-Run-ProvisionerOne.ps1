param([string]$proxySettings)

$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

$outPath = "C:\Program Files\WindowsPowerShell\Modules"
Expand-Archive "C:\provision\bosh-psmodules.zip" -DestinationPath $outPath

#Import-Module -Name BOSH.Utils

Set-ProxySettings $proxySettings

# Move the content of install-bosh-psmodules into here
# directly, rather than calling that script.