@{
RootModule = 'BOSH.Utils'
ModuleVersion = '0.1'
GUID = '1113e65d-b18e-4277-abc8-12c60a8f1f52'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Common Utils on a BOSH deployed vm'
PowerShellVersion = '4.0'
FunctionsToExport = @(
    'Write-Log',
    'Get-Log',
    'Open-Zip',
    'New-Provisioner',
    'Clear-Provisioner',
    'Protect-Dir',
    'Protect-MountedDir',
    'Set-ProxySettings',
    'Clear-ProxySettings',
    'Disable-RC4',
    'Disable-TLS1',
    'Disable-3DES',
    'Disable-DCOM')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('Utils')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
