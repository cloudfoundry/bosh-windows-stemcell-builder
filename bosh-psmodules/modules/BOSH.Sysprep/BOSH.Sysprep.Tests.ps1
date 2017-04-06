Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Import-Module ./BOSH.Sysprep.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Invoke-Sysprep" {
    Context "when not provided an IaaS" {
        It "throws" {
            { Invoke-Sysprep } | Should Throw "Provide the IaaS this stemcell will be used for"
        }
    }

    Context "when provided an invalid Iaas" {
        It "throws" {
            { Invoke-Sysprep -IaaS "OpenShift" } | Should Throw "Invalid IaaS 'OpenShift' supported platforms are: AWS, Azure, GCP and Vsphere"
        }
    }
}

Describe "Enable-LocalSecurityPolicy" {
    BeforeEach {
        $PolicyDestination=(New-TempDir)
    }

    AfterEach {
        Remove-Item -Recurse -Force $PolicyDestination
    }

    It "places the policy files in the destination and runs lgpo.exe" {
        $lgpoExe = "cmd.exe /c 'echo hello'"
        { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Not Throw
        (Test-Path (Join-Path $PolicyDestination "policy-baseline")) | Should Be $True
        (Join-Path $PolicyDestination "lgpo.log") | Should Contain "hello"
    }

    Context "when lgpo.exe fails" {
        It "throws" {
            $lgpoExe = "cmd.exe /c 'exit 1'"
            { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Throw "lgpo.exe exited with 1"
        }
    }
}

Describe "Create-Unattend" {
    BeforeEach {
        $UnattendDestination=(New-TempDir)
        $NewPassword="NewPassword"
        $ProductKey= "ProductKey"
        $Organization="Organization"
        $Owner="Owner"
        {
            Create-Unattend -UnattendDestination $UnattendDestination `
                -NewPassword $NewPassword `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
        } | Should Not Throw
    }

    AfterEach {
        Remove-Item -Recurse -Force $UnattendDestination
    }

    It "places the generated Unattend file in the specified directory" {
        Test-Path (Join-Path $UnattendDestination "unattend.xml") | Should Be $True
    }

    Context "failure scenarios" {
        It "throws when there is no new password provided" {
            {
                Create-Unattend -UnattendDestination $UnattendDestination `
                    -ProductKey $ProductKey `
                    -Organization $Organization `
                    -Owner $Owner
            } | Should Throw "Provide an Administrator Password"
        }

        It "throws when Organization or Owner are not present and Product Key is provided" {
            {
                Create-Unattend -UnattendDestination $UnattendDestination `
                    -NewPassword $NewPassword `
                    -ProductKey $ProductKey
            } | Should Throw "Provide an Organization and Owner"
        }

    }

    Context "the generated Unattend file" {
        BeforeEach {
            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath
            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
        }

        It "contains a New Password" {
            $unattendXML.unattend.settings.component.UserAccounts.AdministratorPassword.Value | Should Be $NewPassword
        }

        It "contains a Product Key, Organization, and Owner when Product Key is provided" {
            $unattendXML.SelectSingleNode("//ns:ProductKey", $ns).'#text' | Should Be $ProductKey
            $unattendXML.SelectSingleNode("//ns:RegisteredOrganization", $ns).'#text' | Should Be $Organization
            $unattendXML.SelectSingleNode("//ns:RegisteredOwner", $ns).'#text' | Should Be $Owner
        }

        It "when Product Key is not provided, there is no Product Key, Organization, or Owner" {
            {
                Create-Unattend -UnattendDestination $UnattendDestination `
                    -NewPassword $NewPassword
            } | Should Not Throw
            [xml]$unattendXML = Get-Content -Path $unattendPath
            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            $unattendXML.SelectSingleNode("//ns:ProductKey", $ns).'#text' | Should Be $Null
            $unattendXML.SelectSingleNode("//ns:RegisteredOrganization", $ns).'#text' | Should Be $Null
            $unattendXML.SelectSingleNode("//ns:RegisteredOwner", $ns).'#text' | Should Be $Null
        }
    }
}

Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
