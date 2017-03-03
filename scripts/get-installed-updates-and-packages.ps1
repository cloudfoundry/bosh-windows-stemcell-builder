<#
.SYNOPSIS
    Collects the installed updates and Windows features and writes them as JSON
    to $UpdatesPath and $FeaturesPath.
#>

param(
    [String]$UpdatesPath="C:\\bosh\\installed-updates.json",
    [String]$FeaturesPath="C:\\bosh\\installed-features.json"
)

$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Import-Module PSWindowsUpdate

function EnableMicrosoftUpdates {
    Stop-Service "wuauserv"

    $scriptPath = "${env:TEMP}\enable-microsoft-updates.vbs"
    cmd.exe /C ('echo Set ServiceManager = CreateObject("Microsoft.Update.ServiceManager") > {0}' -f $scriptPath)
    cmd.exe /C ('echo Set NewUpdateService = ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"") >> {0}' -f $scriptPath)
    (cscript.exe $scriptPath) | Out-Null

    Start-Service "wuauserv"
}

function Get-InstalledUpdates {
    EnableMicrosoftUpdates

    $installedUpdates = (Get-WUList -IsInstalled)

    $list=@()
    foreach ($update in $installedUpdates) {
        $obj = New-Object -TypeName psobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name KB -Value $update.KB
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Title -Value $update.Title
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Status -Value $update.Status
        Add-Member -InputObject $obj -MemberType NoteProperty -Name IsDownloaded -Value $update.IsDownloaded
        Add-Member -InputObject $obj -MemberType NoteProperty -Name IsHidden -Value $update.IsHidden
        Add-Member -InputObject $obj -MemberType NoteProperty -Name IsInstalled -Value $update.IsInstalled
        Add-Member -InputObject $obj -MemberType NoteProperty -Name IsMandatory -Value $update.IsMandatory
        Add-Member -InputObject $obj -MemberType NoteProperty -Name IsUninstallable -Value $update.IsUninstallable
        Add-Member -InputObject $obj -MemberType NoteProperty -Name MsrcSeverity -Value $update.MsrcSeverity
        Add-Member -InputObject $obj -MemberType NoteProperty -Name SecurityBulletinIDs -Value @()
        foreach ($id in $update.SecurityBulletinIDs) {
            $obj.SecurityBulletinIDs += $id
        }
        Add-Member -InputObject $obj -MemberType NoteProperty -Name CveIDs -Value @()
        foreach ($id in $update.CveIDs) {
            $obj.CveIDs += $id
        }
        $list += $obj
    }

    return $list
}

function Get-InstalledFeatures {
    $installedFeatures = (Get-WindowsFeature | Where Installed)

    $list=@()
    foreach ($feature in $installedFeatures) {
        $obj = New-Object -TypeName psobject
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Name -Value $feature.Name
        Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $feature.DisplayName
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Installed -Value $feature.Installed
        Add-Member -InputObject $obj -MemberType NoteProperty -Name InstallState -Value $feature.InstallState
        Add-Member -InputObject $obj -MemberType NoteProperty -Name FeatureType -Value $feature.FeatureType
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Path -Value $feature.Path
        Add-Member -InputObject $obj -MemberType NoteProperty -Name Parent -Value $feature.Parent
        Add-Member -InputObject $obj -MemberType NoteProperty -Name ServerComponentDescriptor -Value $feature.ServerComponentDescriptor
        Add-Member -InputObject $obj -MemberType NoteProperty -Name SubFeatures -Value $feature.SubFeatures
        Add-Member -InputObject $obj -MemberType NoteProperty -Name EventQuery -Value $feature.EventQuery
        Add-Member -InputObject $obj -MemberType NoteProperty -Name AdditionalInfo -Value $feature.AdditionalInfo
        $list += $obj
    }

    return $list
}

Get-InstalledUpdates | ConvertTo-Json | Out-File -FilePath $UpdatesPath -Encoding utf8

Get-InstalledFeatures | ConvertTo-Json | Out-File -FilePath $FeaturesPath -Encoding utf8
