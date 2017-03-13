<#
.Synopsis
    Configure Autologon
.Description
    This cmdlet enables/disables the Autologon
#>

$RegistryKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

function Enable-Autologon {
    Param ([Parameter(Mandatory=$true)][string]$AdministratorPassword)
	
	Write-Log "Enable Autologon"
    Set-ItemProperty -Path $RegistryKey -Name AutoAdminLogon -Value 1 -Force
    Set-ItemProperty -Path $RegistryKey -Name DefaultUserName -Value Administrator -Force
    Set-ItemProperty -Path $RegistryKey -Name DefaultPassword -Value $AdministratorPassword -Force
}

function Disable-Autologon {
    Write-Log "Disable Autologon"
    Set-ItemProperty $RegistryKey -name AutoAdminLogon -value 0
}
