@{
    RootModule = 'AutomationHelpers'
    ModuleVersion = '0.1'
    Author = 'BOSH'
    FunctionsToExport = @('Setup', 'PostReboot')
    RequiredModules = @('BOSH.Agent', 'BOSH.SSHD')
}
