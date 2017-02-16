<#
.SYNOPSIS
   Checks for available updates that are not installed or failed to install.
   The script exits with status code 1 if updates are missing or failed to install,
   otherwise it exits with 0.
#>

Import-Module PSWindowsUpdate

# OperationResultCode enum
#
# Defines the possible results of a download, install, uninstall, or
# verification operation on an update.
#
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa387095(v=vs.85).aspx
#
# typedef enum  {
#   orcNotStarted           = 0,
#   orcInProgress           = 1,
#   orcSucceeded            = 2,
#   orcSucceededWithErrors  = 3,
#   orcFailed               = 4,
#   orcAborted              = 5
# } OperationResultCode;
function ResultCode-ToString {
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [Int]$ResultCode)
    switch ($ResultCode) {
        0 {return "NotStarted"}
        1 {return "InProgress"}
        2 {return "Succeeded"}
        3 {return "SucceededWithErrors"}
        4 {return "Failed"}
        5 {return "Aborted"}
    }
    return "Invalid: $ResultCode"
}

# UpdateOperation enumeration
#
# Defines operations that can be attempted on an update.
#
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa387282(v=vs.85).aspx
#
# typedef enum  {
#   uoInstallation    = 1,
#   uoUninstallation  = 2
# } UpdateOperation;
function UpdateOperation-ToString {
    param([parameter(Mandatory=$true,ValueFromPipeline=$true)] [Int]$Operation)
    switch ($Operation) {
        1 {return "Installation"}
        2 {return "Uninstallation"}
    }
    return "Invalid: $Operation"
}

function EnableMicrosoftUpdates {
    Stop-Service "wuauserv"

    $scriptPath = "${env:TEMP}\enable-microsoft-updates.vbs"
    cmd.exe /C ('echo Set ServiceManager = CreateObject("Microsoft.Update.ServiceManager") > {0}' -f $scriptPath)
    cmd.exe /C ('echo Set NewUpdateService = ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"") >> {0}' -f $scriptPath)
    (cscript.exe $scriptPath) | Out-Null

    Start-Service "wuauserv"
}

# Registers Microsoft Update Service Manager (required for checking updates)
EnableMicrosoftUpdates

$updateErrors=(Get-WUHistory | Where-Object { $_.ResultCode -ne 2 })
if ($updateErrors.Count -eq 0) {
    Exit 0
}

"KB, Operation, ResultCode, HResult, Date"
foreach ($update in $updateErrors) {
    "{0}, {1}: {2}, {3}: {4}, {5}, {6}" -f $update.KB, `
        (UpdateOperation-ToString $update.Operation), $update.Operation, `
        (ResultCode-ToString $update.ResultCode), $update.ResultCode, `
        $update.HResult, $update.Date
}
Exit 1
