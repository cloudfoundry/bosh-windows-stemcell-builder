<#
.Synopsis
    Enables WinRM
.Description
    This cmdlet enables the WinRM endpoint using http and basic auth by default
#>

function Enable-WinRM {
      Write-Log "Start WinRM with defaults"
      runCmd 'winrm quickconfig -q'

      Write-Log "Getting WinRM config"
      runCmd 'winrm get winrm/config'

      Write-Log "Override defaults to allow unlimited shells/processes/memory"
      runCmd 'winrm set winrm/config @{MaxTimeoutms="7200000"}'
      runCmd 'winrm set winrm/config/winrs @{MaxMemoryPerShellMB="0"}'
      runCmd 'winrm set winrm/config/winrs @{MaxProcessesPerShell="0"}'
      runCmd 'winrm set winrm/config/winrs @{MaxShellsPerUser="0"}'
      runCmd 'winrm set winrm/config/winrs @{MaxConcurrentUsers="30"}'
      runCmd 'winrm set winrm/config/service @{MaxConcurrentOperationsPerUser="5000"}'

      Write-Log "Enable HTTP"
      runCmd 'winrm quickconfig -transport:http'

      Write-Log "Enable insecure basic auth over http"
      runCmd 'winrm set winrm/config/service/auth @{Basic="true"}'
      runCmd 'winrm set winrm/config/client/auth @{Basic="true"}'
      runCmd 'winrm set winrm/config/service @{AllowUnencrypted="true"}'

      Write-Log "Win RM listener Address/Port"
      runCmd 'winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"}'

      Write-Log "Ensure the Windows firewall allows WinRM traffic through"
      Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"

      Write-Log "Win RM port open"
      runCmd 'netsh firewall add portopening TCP 5985 "Port 5985"'

      Write-Log "Getting WinRM config after"
      runCmd 'winrm get winrm/config'
}

function runCmd {
   Param(
	 [string]$arg
	)
      $command_log_ouput = & cmd.exe /c $arg

      Write-Log "Running: $arg"
      Write-Log "$command_log_ouput"

      if ($LASTEXITCODE -ne 0) {
	 Write-Log "Error running: $arg"
      }
}

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

function Disable-WinRM {
    Write-Log "Disable WinRM"
    Get-Service | Where-Object { $_.Name -eq "WinRM" } | Set-Service -StartupType Disabled
    Get-Service | Where-Object { $_.Name -eq "WinRM" } | Stop-Service
}
