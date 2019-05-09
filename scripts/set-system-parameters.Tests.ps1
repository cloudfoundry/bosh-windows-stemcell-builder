$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\set-system-parameters.ps1"


Describe "Save-StemcellVersion" {
    It "saves the stemcell version in target file" {
        Mock New-Item {}


    }
}

Describe "Save-StemcellGitSha" {

}