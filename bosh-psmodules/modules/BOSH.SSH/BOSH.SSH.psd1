@{
RootModule = 'BOSH.SSH'
ModuleVersion = '0.1'
GUID = '50c1c4b1-e154-4b07-92bc-718a3efba6b3'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Install Microsoft SSHD'
PowerShellVersion = '4.0'
FunctionsToExport = @('Install-SSHD')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('BOSH', 'SSHD')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
