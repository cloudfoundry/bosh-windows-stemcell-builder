BeforeAll {
    Import-Module ./BOSH.Registry.psm1
}

Describe "BOSH.Registry" {
    BeforeEach {
        $newItemReturn = [pscustomobject]@{"NewPath" = "HKCU:/Path/created";}
        Mock -ModuleName BOSH.Registry New-Item { $newItemReturn }
        # reset for our -parameterfilter mock
#        Mock -ModuleName BOSH.Registry New-Item { $newItemReturn } -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }
    }

    It "Set-InternetExplorerRegistries applies internet explorer settings when valid policy files are generated" {
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text { 0 }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies  { 0 }

        Set-InternetExplorerRegistries

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 2 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 1 -Scope It -ModuleName BOSH.Registry
    }
    It "Set-InternetExplorerRegistries errors out when policy application fails" {
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text { 0 }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies  { 1 }

        { Set-InternetExplorerRegistries } | Should -Throw "Error Applying IE policy:*"

        Assert-MockCalled Invoke-LGPO-Build-Pol-From-Text -Exactly 2 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Invoke-LGPO-Apply-Policies -Exactly 1 -Scope It -ModuleName BOSH.Registry
    }

    It "Set-InternetExplorerRegistries errors out when User policy generation fails and does not attempt policy application" {
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text { 0 } -ParameterFilter {
            $LGPOTextReadPath -like "*machine.txt"
        }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text { 1 } -ParameterFilter {
            $LGPOTextReadPath -like "*user.txt"
        }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies

        { Set-InternetExplorerRegistries } | Should -Throw "Generating IE policy: User"

        Should -ModuleName BOSH.Registry -Invoke Invoke-LGPO-Build-Pol-From-Text -Exactly 2
        Should -ModuleName BOSH.Registry -Invoke Invoke-LGPO-Apply-Policies -Exactly 0
    }

    It "Set-InternetExplorerRegistries errors out when Machine policy generation fails and does not attempt policy application" {
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text { 1 } -ParameterFilter {
            $LGPOTextReadPath -like "*machine.txt"
        }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies

        { Set-InternetExplorerRegistries } | Should -Throw "Generating IE policy: Machine"

        Should -ModuleName BOSH.Registry -Invoke Invoke-LGPO-Build-Pol-From-Text -Exactly 1
        Should -ModuleName BOSH.Registry -Invoke Invoke-LGPO-Apply-Policies -Exactly 0
    }

    It "Set-InternetExplorerRegistries doesn't call Invoke-LGPO-Build-Pol-From-Text if New-Item call for Machine Directory fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock -ModuleName BOSH.Registry New-Item { Throw 'some error' } -ParameterFilter {
            $Path -like "*Machine" -and $PesterBoundParameters['ErrorAction'] -eq "Stop"
        }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies

        { Set-InternetExplorerRegistries } | Should -Throw

        Should -ModuleName BOSH.Registry -Invoke New-Item -Exactly 1
        Should -ModuleName BOSH.Registry -Invoke Invoke-LGPO-Build-Pol-From-Text -Exactly 0
        Should -ModuleName BOSH.Registry -Invoke  Invoke-LGPO-Apply-Policies -Exactly 0
    }


    It "Set-InternetExplorerRegistries doesn't call Invoke-LGPO-Build-Pol-From-Text if New-Item call for User Directory fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock -ModuleName BOSH.Registry New-Item { Throw 'some error' } -ParameterFilter {
            $Path -like "*User" -and $PesterBoundParameters['ErrorAction'] -eq "Stop"
        }
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Build-Pol-From-Text
        Mock -ModuleName BOSH.Registry Invoke-LGPO-Apply-Policies

        { Set-InternetExplorerRegistries } | Should -Throw

        Should -ModuleName BOSH.Registry -Invoke  Invoke-LGPO-Build-Pol-From-Text -Exactly 1
        Should -ModuleName BOSH.Registry -Invoke  Invoke-LGPO-Apply-Policies -Exactly 0
    }
}
