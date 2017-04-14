Remove-Module -Name BOSH.Account -ErrorAction Ignore
Import-Module ./BOSH.Account.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

Describe "Account" {

    Context "when user is not provided" {
        It "throws" {
            { Add-Account } | Should Throw "Provide a user name"
        }
    }

    Context "when password is not provided" {
        It "throws" {
            { Add-Account -User hello } | Should Throw "Provide a password"
        }
    }

    It "Add and remove a new user account" {
        $user = "Provisioner"
        $password = "Password123!"

        Add-Account -User $user -Password $password
        $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
        $existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $user }
        $existing | Should Not Be $null
        Remove-Account -User $user
        $existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $user }
        $existing | Should Be $null
    }
}

Remove-Module -Name BOSH.Account -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
