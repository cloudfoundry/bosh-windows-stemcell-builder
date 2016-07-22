param($ConfigPath="A:\network-interface-settings.xml")

$Logfile = "C:\Windows\Temp\setup-network-interface.log"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Logfile -value "$now $logstring"
   Write-Host $logstring
}

function ValidateNode {
    Param([string]$node, [string]$name)
    if ($node -eq $NULL) {
        LogWrite "Error: NetworkInterfaceSettings missing required node: ${name}"
        exit 1
    }
}

LogWrite "Preparing to setup network interfaces"

try {
    $doc = [xml][IO.File]::ReadAllText($ConfigPath)

    $Address = $doc.NetworkInterfaceSettings.Address
    ValidateNode $Address "Address"

    $Netmask = $doc.NetworkInterfaceSettings.Netmask
    ValidateNode $Netmask "Netmask"

    $Gateway = $doc.NetworkInterfaceSettings.Gateway
    ValidateNode $Gateway "Gateway"

    $InterfaceName = (Get-NetAdapter -Name "Ethernet*").Name
    netsh interface ip set address $InterfaceName static $Address $Netmask $Gateway
    if ($LASTEXITCODE -ne 0) {
        LogWrite "Error Command (netsh interface ip set address ${InterfaceName} " + `
        "static ${Address} ${Netmask} ${Gateway}): exited with code ${LASTEXITCODE}"
        Exit 1
    }
    LogWrite "Updated network interface"

    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ("8.8.8.8", "8.8.4.4")
    LogWrite "Updated DNS server addresses"
} catch {
    LogWrite $_.Exception | Format-List -Force
    Exit 1
}

LogWrite "Successfully setup network interfaces"
Exit 0
