@{
RootModule = 'BOSH.WinRM'
ModuleVersion = '0.1'
GUID = '43f3e65d-b18e-4277-abc8-12c60a8f1f52'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands for WinRM on a BOSH deployed vm'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('Enable-WinRM')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('WinRM')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
