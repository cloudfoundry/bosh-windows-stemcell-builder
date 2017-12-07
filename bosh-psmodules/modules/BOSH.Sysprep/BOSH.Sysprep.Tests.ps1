Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Import-Module ./BOSH.Sysprep.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Enable-OSPartition-Resize" {
    Context "when no answer file path is provided" {
        It "throws" {
            { Enable-OSPartition-Resize } | Should Throw "Cannot bind argument to parameter 'Path' because it is an empty string."
        }
    }

    Context "when provided a nonexistent answer file" {
        It "throws" {
            { Enable-OSPartition-Resize -AnswerFilePath "C:\IDoNotExist.xml" } | Should Throw "Answer file C:\IDoNotExist.xml does not exist"
        }
    }

    Context "when provided an answer file with invalid XML" {
        BeforeEach {
            $BadAnswerXmlDirectory = (New-TempDir)
            $BadAnswerXmlPath = Join-Path $BadAnswerXmlDirectory "bad.xml"

            "bad xml" | Out-File $BadAnswerXmlPath
        }

        AfterEach {
            Remove-Item -Recurse -Force $BadAnswerXmlDirectory
        }

        It "throws" {
            { Enable-OSPartition-Resize -AnswerFilePath $BadAnswerXmlPath } | Should Throw "Cannot convert value `"bad xml`" to type `"System.Xml.XmlDocument`". Error: `"The specified node cannot be inserted as the valid child of this node, because the specified node is the wrong type.`""
        }
    }

    Context "when provided an answer file containing XML but without a 'specialize block'" {
        BeforeEach {
            $BadAnswerXmlDirectory = (New-TempDir)
            $BadAnswerXmlPath = Join-Path $BadAnswerXmlDirectory "invalidanswer.xml"

            "<?xml version=`"1.0`"?> `
<catalog> `
   <book id=`"bk101`"> `
      <author>Gambardella, Matthew</author> `
      <title>XML Developer's Guide</title> `
      <genre>Computer</genre> `
      <price>44.95</price> `
      <publish_date>2000-10-01</publish_date> `
      <description>An in-depth look at creating applications  `
      with XML.</description> `
   </book> `
</catalog>" | Out-File $BadAnswerXmlPath
        }

        AfterEach {
            Remove-Item -Recurse -Force $BadAnswerXmlDirectory
        }

        It "throws" {
            { Enable-OSPartition-Resize -AnswerFilePath $BadAnswerXmlPath } | Should Throw "Answer file does not contain a 'Microsoft-Windows-Deployment' specialize block."
        }
    }

    Context "when provided an answer file which contains valid XML and a 'specialize' block and it does not already contain an ExtendOSPartition block" {
        BeforeEach {
            $GoodAnswerFileDirectory = (New-TempDir)
            $GoodAnswerFilePath = Join-Path $GoodAnswerFileDirectory "validanswer.xml"

            "<unattend>
                <settings pass=`"specialize`">
                    <component name=`"Microsoft-Windows-Deployment`" processorArchitecture=`"x86`" publicKeyToken=`"31bf3856ad364e35`" language=`"neutral`" versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">
                    </component>
                </settings>
            </unattend>" | Out-File $GoodAnswerFilePath
        }

        AfterEach {
            Remove-Item -Recurse -Force $GoodAnswerFileDirectory
        }

        It "adds a resize block to the answer file" {
            Enable-OSPartition-Resize $GoodAnswerFilePath
            $content = [xml](Get-Content $GoodAnswerFilePath)
            $extendBlock = ((($content.unattend.settings|where {$_.pass -eq 'specialize'}).component|where {$_.name -eq "Microsoft-Windows-Deployment"}).ExtendOSPartition.Extend)
            $extendBlock.Count | Should Be 1
            $extendBlock | Should Be 'true'
        }
    }

    Context "when provided an answer file which contains valid XML and a 'specialize' block and it already contains an ExtendOSPartition block" {
        BeforeEach {
            $GoodAnswerFileDirectory = (New-TempDir)
            $GoodAnswerFilePath = Join-Path $GoodAnswerFileDirectory "validanswer.xml"

            "<unattend>
                <settings pass=`"specialize`">
                    <component name=`"Microsoft-Windows-Deployment`" processorArchitecture=`"x86`" publicKeyToken=`"31bf3856ad364e35`" language=`"neutral`" versionScope=`"nonSxS`" xmlns:wcm=`"http://schemas.microsoft.com/WMIConfig/2002/State`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">
                        <ExtendOSPartition>
                            <Extend>false</Extend>
                        </ExtendOSPartition>
                    </component>
                </settings>
            </unattend>" | Out-File $GoodAnswerFilePath
        }

        AfterEach {
            Remove-Item -Recurse -Force $GoodAnswerFileDirectory
        }

        It "sets Extend to true" {
            Enable-OSPartition-Resize $GoodAnswerFilePath
            $content = [xml](Get-Content $GoodAnswerFilePath)
            $extendBlock = ((($content.unattend.settings|where {$_.pass -eq 'specialize'}).component|where {$_.name -eq "Microsoft-Windows-Deployment"}).ExtendOSPartition.Extend)
            $extendBlock.Count | Should Be 1
            $extendBlock | Should Be 'true'
        }
    }
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
