@{
RootModule = 'BOSH.Disk'
ModuleVersion = '0.1'
GUID = '55e568fc-6388-45de-99b7-273b75be75d0'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands for Disk Utilities on a BOSH deployed vm'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('Compress-Disk','Clean-Disk')
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
