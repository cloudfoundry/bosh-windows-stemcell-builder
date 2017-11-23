function Test-InboundPortOpen {
    Param([int]$Port)

    $FirewallRules = Get-NetFirewallrule | Where { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' } | Get-NetFirewallPortFilter | Where { $_.LocalPort -eq $Port }
    return $FirewallRules.Count -ne 0
}

$ReturnCode = 0

if ((Test-InboundPortOpen 5985) -or (Test-InboundPortOpen 5986)) {
    Write-Error "Error: Expected WinRM inbound ports 5985 and 5986 to be closed"
    $ReturnCode = 1
}

Exit $ReturnCode
