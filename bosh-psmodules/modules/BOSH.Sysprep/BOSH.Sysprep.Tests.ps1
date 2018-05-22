Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Import-Module ./BOSH.Sysprep.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Remove-WasPassProcessed" {
    Context "when no answer file path is provided" {
        It "throws" {
            { Remove-WasPassProcessed } | Should Throw "Cannot bind argument to parameter 'Path' because it is an empty string."
        }
    }

    Context "when provided a nonexistent answer file" {
        It "throws" {
            { Remove-WasPassProcessed -AnswerFilePath "C:\IDoNotExist.xml" } | Should Throw "Answer file C:\IDoNotExist.xml does not exist"
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
            { Remove-WasPassProcessed -AnswerFilePath $BadAnswerXmlPath } | Should Throw "Cannot convert value `"bad xml`" to type `"System.Xml.XmlDocument`". Error: `"The specified node cannot be inserted as the valid child of this node, because the specified node is the wrong type.`""
        }
    }

    Context "when provided an answer file which contains valid XML and a 'specialize' block containing 'Microsoft-Windows-Deployment' which has the attribute 'wasPassProcessed'" {
        BeforeEach {
            $answerFileDirectory = (New-TempDir)
            $answerFilePath = Join-Path $answerFileDirectory "validanswer.xml"

            "<unattend>
                <settings pass=`"specialize`" wasPassProcessed=`"true`">
                    <component name=`"Microsoft-Windows-Deployment`">
                    </component>
                </settings>
                <settings pass=`"oobeSystem`" wasPassProcessed=`"false`">
                    <component name=`"Microsoft-Windows-OOBE`">
                    </component>
                </settings>
                <settings pass=`"foo`">
                    <component name=`"Microsoft-Windows-Foo`">
                    </component>
                </settings>
                <settings pass=`"bar`" wasPassProcessed=`"true`">
                    <component name=`"Microsoft-Windows-Deployment`">
                    </component>
                </settings>
            </unattend>" | Out-File $answerFilePath
        }

        AfterEach {
            Remove-Item -Recurse -Force $answerFileDirectory
        }

        It "removes the attribute regardless of its value" {
            Remove-WasPassProcessed $answerFilePath
            $content = [xml](Get-Content $answerFilePath)

            foreach ($specializeBlock in $content.unattend.settings) {
               $specializeBlock.HasAttribute("wasPassProcessed") | Should Be False
            }
        }
    }

    Context "when processing several 'specialize' blocks which have the attribute 'wasProcessed = true'" {
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

        It "does nothing" {
            Remove-WasPassProcessed $GoodAnswerFilePath
            $content = [xml](Get-Content $GoodAnswerFilePath)
            $mwdBlock = ((($content.unattend.settings|where {$_.pass -eq 'specialize'}).component|where {$_.name -eq "Microsoft-Windows-Deployment"}))
            $specializeBlock = $mwdBlock.ParentNode
            $specializeBlock.hasAttribute("wasPassProcessed") | Should Be False
        }
    }
}

Describe "Remove-UserAccounts" {
    Context "when no answer file path is provided" {
        It "throws" {
            { Remove-UserAccounts } | Should Throw "Cannot bind argument to parameter 'Path' because it is an empty string."
        }
    }

    Context "when provided a nonexistent answer file" {
        It "throws" {
            { Remove-UserAccounts -AnswerFilePath "C:\IDoNotExist.xml" } | Should Throw "Answer file C:\IDoNotExist.xml does not exist"
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
            { Remove-UserAccounts -AnswerFilePath $BadAnswerXmlPath } | Should Throw "Cannot convert value `"bad xml`" to type `"System.Xml.XmlDocument`". Error: `"The specified node cannot be inserted as the valid child of this node, because the specified node is the wrong type.`""
        }
    }

    Context "when provided an answer file containing XML but without an 'oobeSystem' block containing 'Microsoft-Windows-Shell-Setup'" {
        BeforeEach {
            $noOOBEXmlDirectory = (New-TempDir)
            $noOOBEXmlPath = Join-Path $noOOBEXmlDirectory "invalidanswer.xml"

            "<unattend>
                <settings pass=`"Not-oobeSystem`">
                    <component name=`"Microsoft-Windows-Shell-Setup`">
                    </component>
                </settings>
            </unattend>" | Out-File $noOOBEXmlPath
        }

        AfterEach {
            Remove-Item -Recurse -Force $noOOBEXmlDirectory
        }

        It "does nothing" {
            { Remove-UserAccounts -AnswerFilePath $noOOBEXmlPath } | Should Throw "Could not locate oobeSystem XML block. You may not be running this function on an answer file."
        }
    }

    Context "when provided a valid XML answer file containing an 'oobeSystem' block which contains a 'Microsoft-Windows-Shell-Setup' block which DOES NOT contain a 'UserAccounts' block" {
        BeforeEach {
            $GoodAnswerFileDirectory = (New-TempDir)
            $GoodAnswerFilePath = Join-Path $GoodAnswerFileDirectory "validanswer.xml"

            "<unattend>
                <settings pass=`"oobeSystem`">
                    <component name=`"Microsoft-Windows-Shell-Setup`">
                    </component>
                </settings>
            </unattend>" | Out-File $GoodAnswerFilePath
        }

        AfterEach {
            Remove-Item -Recurse -Force $GoodAnswerFileDirectory
        }

        It "does nothing" {
            Remove-UserAccounts -AnswerFilePath $GoodAnswerFilePath
            $content = [xml](Get-Content $GoodAnswerFilePath)
            $userAccountsBlock = (($content.unattend.settings|where {$_.pass -eq 'oobeSystem'}).component|where {$_.name -eq "Microsoft-Windows-Shell-Setup"}).UserAccounts
            $userAccountsBlock | Should Be $Null
        }
    }

    Context "when provided a valid XML answer file containing an 'oobeSystem' block which contains a 'Microsoft-Windows-Shell-Setup' block which contains a 'UserAccounts' block" {
        BeforeEach {
            $GoodAnswerFileDirectory = (New-TempDir)
            $GoodAnswerFilePath = Join-Path $GoodAnswerFileDirectory "validanswer.xml"

            "<unattend>
                <settings pass=`"oobeSystem`">
                    <component name=`"Microsoft-Windows-Shell-Setup`">
                        <UserAccounts>
                            <AdministratorPassword>
                                foo
                            </AdministratorPassword>
                        </UserAccounts>
                    </component>
                </settings>
            </unattend>" | Out-File $GoodAnswerFilePath
        }

        AfterEach {
            Remove-Item -Recurse -Force $GoodAnswerFileDirectory
        }

        It "Removes the UserAccounts xml block" {
            Remove-UserAccounts -AnswerFilePath $GoodAnswerFilePath
            $content = [xml](Get-Content $GoodAnswerFilePath)
            $userAccountsBlock = (($content.unattend.settings|where {$_.pass -eq 'oobeSystem'}).component|where {$_.name -eq "Microsoft-Windows-Shell-Setup"}).UserAccounts
            $userAccountsBlock | Should Be $Null
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

Describe "Allow-NTPSync" {
   It "Sets registry keys that allow the clock to be synced when delta is greater than 15 hours" {
			 $oldMaxNegPhaseCorrection = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxNegPhaseCorrection'
			 $oldMaxPosPhaseCorrection = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxPosPhaseCorrection'

    { Allow-NTPSync } | Should Not Throw

			$maxValue = [uint32]::MaxValue
      (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxNegPhaseCorrection' | Should Be $maxValue
      (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config").'MaxPosPhaseCorrection' | Should Be $maxValue

			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name 'MaxNegPhaseCorrection' -Value $oldMaxNegPhaseCorrection
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name 'MaxPosPhaseCorrection' -Value $oldMaxPosPhaseCorrection
   }
}

Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
