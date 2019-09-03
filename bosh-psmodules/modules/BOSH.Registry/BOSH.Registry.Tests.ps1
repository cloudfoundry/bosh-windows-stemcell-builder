Remove-Module -Name BOSH.Registry -ErrorAction Ignore
Import-Module ./BOSH.Registry.psm1

Describe "BOSH.Registry" {
    BeforeEach {
        $newItemReturn = [pscustomobject]@{"NewPath" = "HKCU:/Path/created";}
        Mock New-Item { $newItemReturn } -ModuleName BOSH.Registry
        # reset for our -parameterfilter mock
        Mock New-Item { $newItemReturn } -ModuleName BOSH.Registry -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }
    }

    It "Set-InternetExplorerRegistries applies internet explorer settings when valid policy files are generated" {
        Mock Invoke-LGPO-Build-Pol-From-Text { 0 } -ModuleName BOSH.Registry
        Mock Invoke-LGPO-Apply-Policies  { 0 } -ModuleName BOSH.Registry

        Set-InternetExplorerRegistries

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 2 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 1 -Scope It -ModuleName BOSH.Registry
    }
    It "Set-InternetExplorerRegistries errors out when policy application fails" {
        Mock Invoke-LGPO-Build-Pol-From-Text { 0 } -ModuleName BOSH.Registry
        Mock Invoke-LGPO-Apply-Policies  { 1 } -ModuleName BOSH.Registry

        { Set-InternetExplorerRegistries } | Should -Throw "Error Applying IE policy:"

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 2 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 1 -Scope It -ModuleName BOSH.Registry
    }

    It "Set-InternetExplorerRegistries errors out when User policy generation fails and does not attempt policy application" {
        Mock Invoke-LGPO-Build-Pol-From-Text { 0 } -ModuleName BOSH.Registry -ParameterFilter {
            $LGPOTextReadPath -like "*machine.txt"
        }
        Mock Invoke-LGPO-Build-Pol-From-Text { 1 } -ModuleName BOSH.Registry -ParameterFilter {
            $LGPOTextReadPath -like "*user.txt"
        }

        { Set-InternetExplorerRegistries } | Should -Throw "Generating IE policy: User"

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 2 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 0 -Scope It -ModuleName BOSH.Registry
    }

    It "Set-InternetExplorerRegistries errors out when Machine policy generation fails and does not attempt policy application" {
        Mock Invoke-LGPO-Build-Pol-From-Text { 1 } -ModuleName BOSH.Registry -ParameterFilter {
            $LGPOTextReadPath -like "*machine.txt"
        }

        { Set-InternetExplorerRegistries } | Should -Throw "Generating IE policy: Machine"

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 1 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 0 -Scope It -ModuleName BOSH.Registry
    }

    It "Set-InternetExplorerRegistries doesn't call Invoke-LGPO-Build-Pol-From-Text if New-Item call for Machine Directory fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock New-Item { Throw 'some error' } -ModuleName BOSH.Registry -ParameterFilter {
            $Path -like "*Machine" -and
            $PSBoundParameters['ErrorAction'] -eq "Stop"
        }

        { Set-InternetExplorerRegistries } | Should -Throw

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 0 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 0 -Scope It -ModuleName BOSH.Registry
    }


    It "Set-InternetExplorerRegistries doesn't call Invoke-LGPO-Build-Pol-From-Text if New-Item call for User Directory fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock New-Item { Throw 'some error' } -ModuleName BOSH.Registry -ParameterFilter {
            $Path -like "*User" -and
                    $PSBoundParameters['ErrorAction'] -eq "Stop"
        }

        { Set-InternetExplorerRegistries } | Should -Throw

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 1 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 0 -Scope It -ModuleName BOSH.Registry
    }
}
