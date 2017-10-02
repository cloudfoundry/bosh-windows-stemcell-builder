@{
RootModule = 'BOSH.CFCell'
ModuleVersion = '0.1'
GUID = '43f3e65d-b18e-2134-abc8-12c60a8f1f52'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Commands for CloudFoundry Cell on a BOSH deployed vm'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('disable-service', 'Install-CFFeatures2012','Install-Docker2016','Install-CFFeatures2016','Install-ContainersFeature','Protect-CFCell')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('CloudFoundry')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
