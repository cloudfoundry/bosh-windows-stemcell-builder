<#
.SYNOPSIS
   Changes the administrator password.

.DESCRIPTION
   Changes the admin password, normal Windows password complexity rules apply.
   The password may be provided as an argument or set in the ADMINISTRATOR_PASSWORD
   environment variable.

.EXAMPLE
    Provide the password as an argument.

   ./set-admin-password.ps1 -NewPassword 'Password123!'

.EXAMPLE
    Provide the password as an environment variable.

   $env:ADMINISTRATOR_PASSWORD='Password123!'
   ./set-admin-password.ps1
#>

param($NewPassword=$env:ADMINISTRATOR_PASSWORD)

$AdminUser = [ADSI]"WinNT://${env:computername}/Administrator,User"
$AdminUser.SetPassword($NewPassword)
