@{
    RootModule = 'BOSH.Registry'
    ModuleVersion = '0.1'
    GUID = '5b414c84-d454-4752-9e59-1532f78836e5'
    Author = 'BOSH'
    Copyright = '(c) 2019 BOSH'
    Description = 'Install Microsoft SSHD'
    PowerShellVersion = '4.0'
    FunctionsToExport = @(
        'Set-RegistryProperty'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('BOSH', 'Registry')
            LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
            ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
        }
    }
}
