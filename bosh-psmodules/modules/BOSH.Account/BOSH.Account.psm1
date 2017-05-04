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
    Write-Log "Add-Account"

    Write-Log "Creating new local user $User."
    & NET USER $User $Password /add /y /expires:never

    $Group = "Administrators"

    Write-Log "Adding local user $User to $Group."
    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
    $AdminGroup = $adsi.Children | where {$_.SchemaClassName -eq 'group' -and $_.Name -eq $Group }
    $UserObject = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $User }
    $AdminGroup.Add($UserObject.Path)
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
    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
    $adsi.Delete('User', $User)
    Move-Item -Path "C:\Users\$User" -Destination "$env:windir\Temp\$User" -Force
}
