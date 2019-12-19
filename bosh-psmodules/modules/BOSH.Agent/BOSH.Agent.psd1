@{
RootModule = 'BOSH.Agent'
ModuleVersion = '0.1'
GUID = 'f46b71ee-4312-4f80-34c7-665d64250ae8'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Install BOSH-Agent on a BOSH deployed vm'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('Install-Agent')
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
