Remove-Module -Name BOSH.Registry -ErrorAction Ignore
Import-Module ./BOSH.Registry.psd1

Describe "BOSH.Registry" {
    BeforeEach {
        Mock Set-ItemProperty { } -ModuleName BOSH.Registry #actually
        $newItemReturn = [pscustomobject]@{"NewPath" = "HKCU:/Path/created";}
        Mock New-Item { $newItemReturn } -ModuleName BOSH.Registry
        # reset for our -parameterfilter mock
        Mock New-Item { $newItemReturn } -ModuleName BOSH.Registry -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }
    }

    It "Set-RegistryProperty adds a property to the registry" {
        {Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A Registry Key" -Value "yes"} | Should -Not -Throw

        Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKLM:/Some/Registry/Path" -and $Name -eq "A Registry Key" -and $Value -eq "yes"
        }
    }

    It "Set-RegistryProperty ensures the folder exists, before modifying the registry property" {
        {Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A Registry Key" -Value "yes"} | Should -Not -Throw

        Assert-MockCalled New-Item -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKLM:/Some/Registry/Path" -and $ItemType -eq "Directory" -and $Force -eq $True
        }
    }

    It "a list of items piped to Set-Registry causes every item in the list to have a key value set" {
        $keyList = @(
            [pscustomobject]@{"Path" = "HKCU:/Registry/Key/Path/One"; "Name" = "RegistryOne"; "Value" = "1"},
            [pscustomobject]@{"Path" = "HKCU:/Registry/Key/Path/Two"; "Name" = "RegistryTwo"; "Value" = "2"},
            [pscustomobject]@{"Path" = "HKCU:/Registry/Key/Path/Three"; "Name" = "RegistryThree"; "Value" = "3"}
        )

        $keyList | Set-RegistryProperty

        Assert-MockCalled Set-ItemProperty -Exactly 3 -Scope It -ModuleName BOSH.Registry
        Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKCU:/Registry/Key/Path/One" -and $Name -eq "RegistryOne" -and $Value -eq "1"
        }
        Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKCU:/Registry/Key/Path/Two" -and $Name -eq "RegistryTwo" -and $Value -eq "2"
        }
        Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKCU:/Registry/Key/Path/Three" -and $Name -eq "RegistryThree" -and $Value -eq "3"
        }
    }

    It "Set-RegistryProperty doesn't call Set-ItemProperty if New-Item fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock New-Item { Throw 'some error' } -ModuleName BOSH.Registry -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }

        { Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A reigstry Key" -Value "no" } | Should -Throw

        Assert-MockCalled Set-ItemProperty -Exactly 0 -Scope It -ModuleName BOSH.Registry
    }

    It "Set-RegistryProperty throws path couldn't be created if New-Item fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a New-Item call that is configured to throw errors
        Mock New-Item { Throw 'some error' } -ModuleName BOSH.Registry -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }

        { Set-RegistryProperty -Path "Something" -Name "Thing" -Value "no" } | Should -Throw "Unable to create path 'Something'"
    }

    It "Set-RegistryProperty throws could not set registry key if Set-ItemProperty fails" {
        # ErrorAction Parameterfilter is present to ensure we only throw an error on a Set-ItemProperty call that is configured to throw errors
        Mock Set-ItemProperty { Throw 'some error'  } -ModuleName BOSH.Registry -ParameterFilter { $PSBoundParameters['ErrorAction'] -eq "Stop" }

        {Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A Registry Key" -Value "yes"} |
            Should -Throw "Unable to set registry key at 'HKLM:/Some/Registry/Path'"
    }

    It "Set-InternetExplorerRegistries imports internet-explorer.csv and pipes to Set-RegistryProperty" {
        Mock Import-Csv { [pscustomobject]@{"Path" = "a"; "Name" = "b"; "Value" = "c"} } -ModuleName BOSH.Registry
        Mock Set-RegistryProperty { } -ModuleName BOSH.Registry

        { Set-InternetExplorerRegistries } | Should -Not -Throw

        $expectedPath = Join-Path -Path $PSScriptRoot -ChildPath "data\internet-explorer.csv"

        Assert-MockCalled Import-Csv -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq $expectedPath
        }
        Assert-MockCalled Set-RegistryProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "a" -and $Name -eq "b" -and $Value -eq "c"
        }
    }
}
