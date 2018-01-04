@{
RootModule = 'BOSH.WindowsUpdates'
ModuleVersion = '0.1'
GUID = 'f46b71ee-e11d-4f80-34c7-665d64250ae8'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Install Windows Updates on a BOSH deployed vm'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils','BOSH.WinRM','BOSH.Autologon')
FunctionsToExport = @('Install-WindowsUpdates',
                      'Register-WindowsUpdatesTask',
                      'Unregister-WindowsUpdatesTask',
                      'Wait-WindowsUpdates',
                      'Test-InstalledUpdates',
                      'Install-KB4056898',
                      'Disable-AutomaticUpdates')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('Windows', 'Updates')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
