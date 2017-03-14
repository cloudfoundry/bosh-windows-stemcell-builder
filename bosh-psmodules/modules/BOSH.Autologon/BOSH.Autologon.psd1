@{
RootModule = 'BOSH.Autologon'
ModuleVersion = '0.1'
GUID = 'eee3e65d-b18e-4277-abc8-12c60a8f1f52'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands to enable/disable Autologon on a BOSH deployed vm'
RequiredModules = @('BOSH.Utils')
PowerShellVersion = '4.0'
FunctionsToExport = @('Enable-Autologon','Disable-Autologon','Test-Autologon')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('Autologon')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
