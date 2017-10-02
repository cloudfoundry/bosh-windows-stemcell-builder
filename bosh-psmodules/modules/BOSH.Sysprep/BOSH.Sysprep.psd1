@{
RootModule = 'BOSH.Sysprep'
ModuleVersion = '0.1'
GUID = '04423ce2-cb12-41ae-b33c-f236f1d0d567'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands for Running Sysprep to create BOSH deployable VM'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils', 'BOSH.WinRM')
FunctionsToExport = @('Enable-LocalSecurityPolicy', 'Create-Unattend', 'Invoke-Sysprep')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('BOSH','LocalSecurityPolicy','Sysprep')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
