Remove-Module -Name BOSH.WindowsUpdates -ErrorAction Ignore
Import-Module ./BOSH.WindowsUpdates.psm1


Describe "List-Updates" {
    It "lists upddates" {
       $result = List-Updates
       $result.Length | Should BeGreaterThan 0
       $result[0] | Should BeLike 'KB*'
    }
}
