Remove-Module -Name BOSH.Registry -ErrorAction Ignore
Import-Module ./BOSH.Registry.psd1

Describe "BOSH.Registry" {
    BeforeEach {
        Mock Set-ItemProperty { } -ModuleName BOSH.Registry
        Mock New-Item { } -ModuleName BOSH.Registry
    }

    It "Set-RegistryProperty adds a property to the registry" {
        Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A Registry Key" -Value "yes"

        Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKLM:/Some/Registry/Path" -and $Name -eq "A Registry Key" -and $Value -eq "yes"
        }
    }

    It "Set-RegistryProperty ensures the folder exists, before modifying the registry property" {
        Set-RegistryProperty -Path "HKLM:/Some/Registry/Path" -Name "A Registry Key" -Value "yes"

        Assert-MockCalled New-Item -Exactly 1 -Scope It -ModuleName BOSH.Registry -ParameterFilter {
            $Path -eq "HKLM:/Some/Registry/Path" -and $ItemType -eq "Directory"
        }
    }
}
