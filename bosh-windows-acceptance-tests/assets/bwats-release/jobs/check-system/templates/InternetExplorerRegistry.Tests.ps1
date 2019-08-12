Describe "Internet Explorer Registry Settings" {
    [hashtable]$registryTypeAbbreviations = @{
        "HKCU:" = "HKEY_CURRENT_USER";
        "HKLM:" = "HKEY_LOCAL_MACHINE";
    }

    BeforeAll {
        $expectedRegistryEntries = Import-Csv "$PSScriptRoot/../config/internet-explorer-policies.csv"
    }

    foreach ($expectedEntry in $expectedRegistryEntries)
    {
        It "$( $expectedEntry.Path ) property $( $expectedEntry.Name ) is '$( $expectedEntry.Value )'" {
            $pathComponents = $expectedEntry.Path.Split("\")

            $longType = $registryTypeAbbreviations[$pathComponents[0]]

            For ($i = 0; $i -lt ($pathComponents.Count - 1); $i++) {
                $testPath = $pathComponents[0..$i] -Join "\"
                $Path = $pathComponents[1..($i + 1)] -Join "\"
                $expectedChild = "$longType\$Path"
                (Get-ChildItem -Path $testPath | Select -Property Name).Name |
                        Should -Contain $expectedChild -Because "$testPath\ should include the child entry $( $pathComponents[$i + 1] )"
            }

            $registryElement = Get-ItemProperty -Path $expectedEntry.Path

            [bool]($registryElement.PSObject.Properties.name -match $expectedEntry.Name) |
                    Should -Be $true -Because "$( $expectedEntry.Path ) should include property $( $expectedEntry.Name )"

            $registryElement."$( $expectedEntry.Name )" | Should -Be $expectedEntry.Value
        }
    }
}
