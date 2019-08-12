<#
.Synopsis
    Apply a registry property, ensuring the path to the registry exists
.Description
    This cmdlet ensures the registry exists before configuring the requested property
.Parameter Path
    The path of the registry the property should be associated with
.Parameter Name
    The name of the registry property
.Parameter Value
    The value of the registry property
#>
Function Set-RegistryProperty {
    Param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    New-Item -Path $Path -ItemType "Directory"

    Set-ItemProperty -Path $Path -Name $Name -Value $Value
}
