function Set-RegistryProperty {
    <#
    .SYNOPSIS
        Apply a registry property, ensuring the path to the registry exists
    .DESCRIPTION
        This cmdlet ensures the registry exists before configuring the requested property
    .PARAMETER Path
        The path of the registry the property should be associated with
    .PARAMETER Name
        The name of the registry property
    .PARAMETER Value
        The value of the registry property
    .INPUTS
        Any object, or list of objects with properties names Path, Name & Value
    .OUTPUTS
        If successful Set-RegistryProperty will not return any output, however it will throw an exception if any part
        of the command fails
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Path,
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Value
    )

    Process {
        try{
            New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "Stop"
        } catch {
            throw "Unable to create path '$Path':$_"
        }
        try {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction "Stop" #[System.Management.Automation.ActionPreference]::Stop
        } catch {
            throw "Unable to set registry key at '$Path':$_"
        }
    }
}

function Set-InternetExplorerRegistries {
    <#
    .SYNOPSIS
        Apply BOSH Windows Stemcell registry settings related to internet explorer
    .DESCRIPTION
        Apply Internet Explorer registry settings taken from Microsoft's baseline security analysis tool
    .INPUTS
        None. You can't pipe anything in to this command
    .OUTPUTS
        Set-InternetExplorerRegistries will return any failure output from Import-Csv or Set-RegistryProperty
    #>

    [CmdletBinding()]

    param()

    process {
        $source = Join-Path -Path $PSScriptRoot -ChildPath "data\internet-explorer.csv"
        Import-Csv -Path $source | Set-RegistryProperty
    }
}