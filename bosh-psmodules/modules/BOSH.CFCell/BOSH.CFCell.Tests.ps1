Remove-Module -Name BOSH.CFCell -ErrorAction Ignore
Import-Module ./BOSH.CFCell.psm1


Describe "Protect-CFCell" {
    It "enables the RDP service and firewall rule" {
       Protect-CFCell
       netstat /p tcp /a | findstr 3389 | Should Not BeNullOrEmpty
    }
}
