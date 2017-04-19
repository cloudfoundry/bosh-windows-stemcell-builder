function Write-Log {
   Param (
   [Parameter(Mandatory=$True,Position=1)][string]$Message,
   [string]$LogFile="C:\provision\log.log"
   )

   $LogDir = (split-path $LogFile -parent)
   If ((Test-Path $LogDir) -ne $True) {
     New-Item -Path $LogDir -ItemType Directory -Force
   }

   $msg = "{0} {1}" -f (Get-Date -Format o), $Message
   Add-Content -Path $LogFile -Value $msg -Encoding 'UTF8'
   Write-Host $msg
}

$winrmUrl = 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/consolidate-winrm/bosh-psmodules/modules/BOSH.WinRM/BOSH.WinRM.psm1'
Write-Log "Making bosh module directory"
$dir = 'C:\Program Files\WindowsPowerShell\Modules\BOSH.WinRM'
New-Item -Path $dir -ItemType Directory -Force

Write-Log "Fetching bosh module"
Invoke-WebRequest $winrmUrl -OutFile "$dir\BOSH.WinRM.psm1"

if (-not(Get-Command Enable-WinRM -errorAction SilentlyContinue))
{
    Write-Log "Enable-WinRM was not loaded. There may be a problem with $winrmUrl" 
}

Write-Log "Invoking winrm"
Enable-WinRM
