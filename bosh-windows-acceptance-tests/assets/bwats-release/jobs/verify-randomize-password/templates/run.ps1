$ErrorActionPreference = "Stop"

secedit /configure /db secedit.sdb /cfg c:\var\vcap\jobs\verify-randomize-password\inf\security.inf

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$ComputerName=hostname
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)

if ($DS.ValidateCredentials('Administrator', 'Password123!')) {
    Write-Error "Administrator password was not randomized"
    Exit 1
}
