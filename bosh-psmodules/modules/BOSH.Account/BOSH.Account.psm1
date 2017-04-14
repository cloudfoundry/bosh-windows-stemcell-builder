<#
.Synopsis
    Add Windows user
.Description
    This cmdlet adds a Windows user
#>
function Add-Account {
    Param(
            [string]$User = $(Throw "Provide a user name"),
            [string]$Password = $(Throw "Provide a password")
         )
    $group = "Administrators"

    Write-Log "Add-Account"
    Write-Log "Creating new local user $User."
    & NET USER $User $Password /add /y /expires:never
    Write-Log "Adding local user $User to $group."
    & NET LOCALGROUP $group $Username /add
}

<#
.Synopsis
Remove Windows user
.Description
This cmdlet removes a Windows user
#>
function Remove-Account {
    Param(
            [string]$User = $(Throw "Provide a user name")
         )
    Write-Log "Remove-Account"
    Write-Log "Removing local user $User."
    & NET USER $User /delete /y
}
