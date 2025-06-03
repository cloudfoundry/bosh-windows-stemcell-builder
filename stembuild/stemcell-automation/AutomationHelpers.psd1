@{
    RootModule = 'AutomationHelpers'
    ModuleVersion = '0.1'
    Author = 'BOSH'
    FunctionsToExport = @('Setup', 'PostReboot', 'Write-Log')
    RequiredModules = @('BOSH.Agent', 'BOSH.SSHD')
}
