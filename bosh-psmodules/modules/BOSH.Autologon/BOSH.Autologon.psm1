<#
.Synopsis
    Configure Autologon
.Description
    This cmdlet enables/disables the Autologon
#>

$RegistryKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

function Enable-Autologon {
    Param (
        [Parameter(Mandatory=$true)][string]$Password,
        [string]$User="Provisioner"
    )

    Write-Log "Enabling Autologon"
    Set-ItemProperty -Path $RegistryKey -Name AutoAdminLogon -Value 1 -Force
    Set-ItemProperty -Path $RegistryKey -Name AutoLogonCount -Value 5 -Force
    Set-ItemProperty -Path $RegistryKey -Name DefaultUserName -Value $User -Force
    Set-ItemProperty -Path $RegistryKey -Name DefaultPassword -Value $Password -Force

    Get-ItemProperty -Path $RegistryKey
}

function Disable-Autologon {
    Write-Log "Disable Autologon"
    Set-ItemProperty $RegistryKey -name AutoAdminLogon -value 0
}
