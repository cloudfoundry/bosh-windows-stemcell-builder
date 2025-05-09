@{
RootModule = 'BOSH.Account'
ModuleVersion = '0.1'
GUID = 'ebdf7a79-39df-46ce-a046-42dd10de82ce'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands for creating a new Windows user'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('Add-Account','Remove-Account')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('BOSH')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
