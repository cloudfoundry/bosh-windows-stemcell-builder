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

Describe "ModifyInfFile" {
    BeforeEach {
        $InfFileDirectory = (New-TempDir)
        $InfFilePath = Join-Path $InfFileDirectory "infFile.inf"

        "something=something`nkey=blah`nx=x" | Out-File $InfFilePath
    }

    AfterEach {
        Remove-Item -Recurse -Force $InfFileDirectory
    }

    It "modifies the inf key" {
        ModifyInfFile -InfFilePath $InfFilePath -KeyName 'key' -KeyValue 'value'

        $actual = (Get-Content $InfFilePath) -join "`n"

        $actual | Should Be "something=something`nkey=value`nx=x"
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

    It "handles special chars in passwords" {
        $NewPassword = "<!--Password123"
        {
        Create-Unattend -UnattendDestination $UnattendDestination `
                -NewPassword $NewPassword `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
        } | Should Not Throw

        $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
        [xml]$unattendXML = Get-Content -Path $unattendPath

        $encodedPassword = $unattendXML.unattend.settings.component.UserAccounts.AdministratorPassword.Value
        [system.text.encoding]::Unicode.GetString([system.convert]::Frombase64string($encodedPassword)) | Should Be ($newPassword + "AdministratorPassword")
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
    }

    Context "the generated Unattend file" {
        BeforeEach {
            $unattendPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $unattendPath
            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
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
        }

        It "when Product Key is not provided: Organization and Owner are not removed" {
            {
                Create-Unattend -UnattendDestination $UnattendDestination `
                    -NewPassword $NewPassword -Organization 'Test-Org' -Owner 'Test-Owner'
            } | Should Not Throw
            [xml]$unattendXML = Get-Content -Path $unattendPath
            $ns = New-Object System.Xml.XmlNamespaceManager($unattendXML.NameTable)
            $ns.AddNamespace("ns", $unattendXML.DocumentElement.NamespaceURI)
            $unattendXML.SelectSingleNode("//ns:RegisteredOrganization", $ns).'#text' | Should Be 'Test-Org'
            $unattendXML.SelectSingleNode("//ns:RegisteredOwner", $ns).'#text' | Should Be 'Test-Owner'
        }
    }
}

Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
