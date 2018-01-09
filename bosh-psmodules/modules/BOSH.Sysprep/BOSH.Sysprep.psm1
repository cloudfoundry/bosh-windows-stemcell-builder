<#
.Synopsis
    Sysprep Utilities
.Description
    This cmdlet enables enabling a local security policy for a stemcell
#>
function Enable-LocalSecurityPolicy {
    Param (
        [string]$PolicySource = (Join-Path $PSScriptRoot "cis-merge")
    )

    Write-Log "Starting LocalSecurityPolicy"

    # Convert registry.txt files into registry.pol files
    $MachineDir="$PolicySource/DomainSysvol/GPO/Machine"
    LGPO.exe /r "$MachineDir/registry.txt" /w "$MachineDir/registry.pol"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Generating policy: Machine"
    }

    $UserDir="$PolicySource/DomainSysvol/GPO/User"
    LGPO.exe /r "$UserDir/registry.txt" /w "$UserDir/registry.pol"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Generating policy: User"
    }

    # Apply policies
    LGPO.exe /g "$PolicySource/DomainSysvol" /v
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Applying policy: $PolicySource/DomainSysvol"
    }

    Write-Log "Ending LocalSecurityPolicy"
}

<#
.Synopsis
    Sysprep Utilities
.Description
    This cmdlet creates the Unattend file for sysprep
#>
function Create-Unattend {
    Param (
        [string]$UnattendDestination = "C:\Windows\Panther\Unattend",
        [string]$NewPassword = $(Throw "Provide an Administrator Password"),
        [string]$ProductKey,
        [string]$Organization,
        [string]$Owner
    )

    $NewPassword = [system.convert]::ToBase64String([system.text.encoding]::Unicode.GetBytes($NewPassword + "AdministratorPassword"))
    Write-Log "Starting Create-Unattend"

    New-Item -ItemType directory $UnattendDestination -Force
    $UnattendPath = Join-Path $UnattendDestination "unattend.xml"

    Write-Log "Writing unattend.xml to $UnattendPath"

    $ProductKeyXML=""
    if ($ProductKey -ne "") {
        $ProductKeyXML="<ProductKey>$ProductKey</ProductKey>"
    }

    $OrganizationXML="<RegisteredOrganization />"
    if ($Organization -ne "" -and $Organization -ne $null) {
        $OrganizationXML="<RegisteredOrganization>$Organization</RegisteredOrganization>"
    }

    $OwnerXML="<RegisteredOwner />"
    if ($Owner -ne "" -and $Owner -ne $null) {
        $OwnerXML="<RegisteredOwner>$Owner</RegisteredOwner>"
    }

    $PostUnattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OEMInformation>
                <HelpCustomized>false</HelpCustomized>
            </OEMInformation>
            <ComputerName>*</ComputerName>
            <TimeZone>UTC</TimeZone>
            $ProductKeyXML
            $OrganizationXML
            $OwnerXML
        </component>
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
        </component>
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-OutOfBoxExperience" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <DoNotOpenInitialConfigurationTasksAtLogon>true</DoNotOpenInitialConfigurationTasksAtLogon>
        </component>
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
    </settings>
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>false</PersistAllDeviceInstalls>
            <DoNotCleanUpNonPresentDevices>false</DoNotCleanUpNonPresentDevices>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <ProtectYourPC>3</ProtectYourPC>
                <NetworkLocation>Home</NetworkLocation>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            </OOBE>
            <TimeZone>UTC</TimeZone>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$NewPassword</Value>
                    <PlainText>false</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
</unattend>
"@

    Out-File -FilePath $UnattendPath -InputObject $PostUnattend -Encoding utf8

    Write-Log "Starting Create-Unattend"
}

<#
.Synopsis
    Sanity check that the unattend.xml shipped with GCP has not changed.
.Description
    Sanity check that the unattend.xml shipped with GCP has not changed.
#>
function Check-Default-GCP-Unattend() {

    [xml]$Expected = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!--
    For more information about unattended.xml please refer too
    http://technet.microsoft.com/en-us/library/cc722132(v=ws.10).aspx
    -->
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ExtendOSPartition>
                <Extend>true</Extend>
            </ExtendOSPartition>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <!-- Random ComputerName, will be replaced by specialize script -->
            <ComputerName></ComputerName>
            <TimeZone>Greenwich Standard Time</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <!-- Setting Location Information -->
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UserLocale>en-us</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <!-- Setting EULA -->
                <HideEULAPage>true</HideEULAPage>
                <!-- Setting network location to public -->
                <NetworkLocation>Other</NetworkLocation>
                <!-- Hide Wirelss setup -->
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <!-- Setting timezone to GMT -->
            <ShowWindowsLive>false</ShowWindowsLive>
            <TimeZone>Greenwich Standard Time</TimeZone>
            <!--Setting OEM information -->
            <OEMInformation>
                <Manufacturer>Google Cloud Platform</Manufacturer>
                <Model>Google Compute Engine Virtual Machine</Model>
                <SupportURL>https://support.google.com/enterprisehelp/answer/142244?hl=en#cloud</SupportURL>
                <Logo>C:\Program Files\Google Compute Engine\sysprep\gcp.bmp</Logo>
            </OEMInformation>
        </component>
    </settings>
</unattend>
'@

  $UnattendPath = "C:\Program Files\Google\Compute Engine\sysprep\unattended.xml"
  [xml]$Unattend = (Get-Content -Path $UnattendPath)

  if (-Not ($Unattend.xml.Equals($Expected.xml))) {
    Write-Error "The unattend.xml shipped with GCP has changed."
  }
}

function Create-Unattend-GCP() {
  $UnattendXML = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!--
    For more information about unattended.xml please refer too
    http://technet.microsoft.com/en-us/library/cc722132(v=ws.10).aspx
    -->
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ExtendOSPartition>
                <Extend>true</Extend>
            </ExtendOSPartition>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <!-- Random ComputerName, will be replaced by specialize script -->
            <ComputerName></ComputerName>
            <TimeZone>Greenwich Standard Time</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <!-- Setting Location Information -->
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UserLocale>en-us</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <!-- Setting EULA -->
                <HideEULAPage>true</HideEULAPage>
                <!-- Setting network location to public -->
                <NetworkLocation>Other</NetworkLocation>
                <!-- Hide Wirelss setup -->
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <!-- Setting timezone to GMT -->
            <ShowWindowsLive>false</ShowWindowsLive>
            <TimeZone>Greenwich Standard Time</TimeZone>
            <!--Setting OEM information -->
            <OEMInformation>
                <Manufacturer>Google Cloud Platform</Manufacturer>
                <Model>Google Compute Engine Virtual Machine</Model>
                <SupportURL>https://support.google.com/enterprisehelp/answer/142244?hl=en#cloud</SupportURL>
                <Logo>C:\Program Files\Google Compute Engine\sysprep\gcp.bmp</Logo>
            </OEMInformation>
        </component>
    </settings>
</unattend>
'@

  $UnattendPath = "C:\Program Files\Google\Compute Engine\sysprep\unattended.xml"
  Out-File -FilePath $UnattendPath -InputObject $UnattendXML -Encoding utf8 -Force
}

function Enable-OSPartition-Resize {
    Param (
        [string]$AnswerFilePath
    )

    If (!$(Test-Path $AnswerFilePath)) {
        Throw "Answer file $AnswerFilePath does not exist"
    }

    Write-Log "Enabling Partition Resizing"

    $content = [xml](Get-Content $AnswerFilePath)

    $deploymentComponent = (($content.unattend.settings|where {$_.pass -eq 'specialize'}).component|where {$_.name -eq "Microsoft-Windows-Deployment"})
    If ($deploymentComponent.Count -eq 0) {
        Throw "Answer file does not contain a 'Microsoft-Windows-Deployment' specialize block."
    }

    $existingExtendOSPartitionBlock = ((($content.unattend.settings|where {$_.pass -eq 'specialize'}).component|where {$_.name -eq "Microsoft-Windows-Deployment"}).ExtendOSPartition)
    $extend = $content.CreateElement("Extend", $content.DocumentElement.NamespaceURI)
    $extend.InnerText = "true"

    If ($existingExtendOSPartitionBlock.Extend.Count -eq 0) {
        $extendOSPartition = $content.CreateElement("ExtendOSPartition", $content.DocumentElement.NamespaceURI)
        $extendOSPartition.AppendChild($extend)

        $deploymentComponent.AppendChild($extendOSPartition)
    } Else {
        $existingExtendOSPartitionBlock.ReplaceChild($extend, $existingExtendOSPartitionBlock.SelectSingleNode("//Extend"))
    }

    $content.Save($AnswerFilePath)
}

function Remove-WasPassProcessed {
    Param (
        [string]$AnswerFilePath
    )

    If (!$(Test-Path $AnswerFilePath)) {
        Throw "Answer file $AnswerFilePath does not exist"
    }

    Write-Log "Removing wasPassProcessed"

    $content = [xml](Get-Content $AnswerFilePath)

    foreach ($specializeBlock in $content.unattend.settings) {
        $specializeBlock.RemoveAttribute("wasPassProcessed")
    }

    $content.Save($AnswerFilePath)
}

function Remove-UserAccounts {
    Param (
        [string]$AnswerFilePath
    )

    If (!$(Test-Path $AnswerFilePath)) {
        Throw "Answer file $AnswerFilePath does not exist"
    }

    Write-Log "Removing UserAccounts block from Answer File"

    $content = [xml](Get-Content $AnswerFilePath)
    $mswShellSetup =  (($content.unattend.settings|where {$_.pass -eq 'oobeSystem'}).component|where {$_.name -eq "Microsoft-Windows-Shell-Setup"})

    if ($mswShellSetup -eq $Null) {
        Throw "Could not locate oobeSystem XML block. You may not be running this function on an answer file."
    }

    $userAccountsBlock = $mswShellSetup.UserAccounts

    if ($userAccountsBlock.Count -eq 0) {
        Return
    }

    $mswShellSetup.RemoveChild($userAccountsBlock)

    $content.Save($AnswerFilePath)
}

<#
.Synopsis
    Sysprep Utilities
.Description
    This cmdlet runs Sysprep and generalizes a VM so it can be a BOSH stemcell
#>
function Invoke-Sysprep() {
    Param (
        [string]$IaaS = $(Throw "Provide the IaaS this stemcell will be used for"),
        [string]$NewPassword="",
        [string]$ProductKey="",
        [string]$Organization="",
        [string]$Owner="",
        [string]$OsVersion="windows2012R2",
        [switch]$SkipLGPO,
        [switch]$EnableRDP
    )

    Write-Log "Invoking Sysprep for IaaS: ${IaaS}"

    # WARN WARN: this should be removed when Microsoft fixes this bug
    # See tracker story https://www.pivotaltracker.com/story/show/150238324
    # Skip sysprep if using Windows Server 2016 insider build with UALSVC bug
    $RegPath="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    If ((Get-ItemProperty -Path $RegPath).CurrentBuildNumber -Eq '16278') {
      Stop-Computer
    }

    switch ($IaaS) {
        "aws" {
            switch ($OsVersion) {
                "windows2012R2" {
                    Enable-OSPartition-Resize -AnswerFilePath "C:\Program Files\Amazon\Ec2ConfigService\sysprep2008.xml"

                    $ec2config = [xml] (get-content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml')

                    # Enable password generation and retrieval
                    ($ec2config.ec2configurationsettings.plugins.plugin | where { $_.Name -eq "Ec2SetPassword" }).State = 'Enabled'

                    # Disable SetDnsSuffixList setting
                    $ec2config.ec2configurationsettings.GlobalSettings.SetDnsSuffixList = "false"

                    $ec2config.Save("C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml")

                    # Enable sysprep
                    $ec2settings = [xml] (get-content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\BundleConfig.xml')
                    ($ec2settings.BundleConfig.Property | where { $_.Name -eq "AutoSysprep" }).Value = 'Yes'

                    # Don't shutdown when running sysprep, let packer do it
                    ($ec2settings.BundleConfig.GeneralSettings.Sysprep | where { $_.AnswerFilePath -eq "sysprep2008.xml" }).Switches = "/oobe /quit /generalize"

                    $ec2settings.Save('C:\Program Files\Amazon\Ec2ConfigService\Settings\BundleConfig.xml')
                    Start-Process "C:\Program Files\Amazon\Ec2ConfigService\Ec2Config.exe" -ArgumentList "-sysprep" -Wait
                }
                "windows2016" {
                    # Enable password generation and retrieval
                    # LaunchConfig.json adminPasswordType defaults to "Random"
                    # TODO: should we set this value to "DoNothing"? Since the BOSH Agent will always randomize the password.
                    # We can use the BOSH Agent to set the password to a specific value.

                    # Disable SetDnsSuffixList setting
                    $LaunchConfigJson = 'C:\ProgramData\Amazon\EC2-Windows\Launch\Config\LaunchConfig.json'
                    $LaunchConfig = Get-Content $LaunchConfigJson -raw | ConvertFrom-Json
                    $LaunchConfig.addDnsSuffixList = $False
                    $LaunchConfig | ConvertTo-Json | Set-Content $LaunchConfigJson

                    # Enable sysprep
                    cd 'C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts'
                    ./InitializeInstance.ps1 -Schedule
                    ./SysprepInstance.ps1
                }
            }
        }
        "gcp" {
            Create-Unattend-GCP
            GCESysprep
        }
        "azure" {
            $AnswerFilePath = "C:\Windows\Panther\unattend.xml"
            Enable-OSPartition-Resize -AnswerFilePath $AnswerFilePath
            Remove-WasPassProcessed -AnswerfilePath $AnswerFilePath
            Remove-UserAccounts -AnswerFilePath $AnswerFilePath

            C:\Windows\System32\Sysprep\sysprep.exe /generalize /quiet /oobe /quit /unattend:$AnswerFilePath
        }
        "vsphere" {
            if (-Not $SkipLGPO) {
                if (-Not (Test-Path "C:\Windows\LGPO.exe")) {
                    Throw "Error: LGPO.exe is expected to be installed to C:\Windows\LGPO.exe"
                }
                Enable-LocalSecurityPolicy
            }

            Create-Unattend -NewPassword $NewPassword -ProductKey $ProductKey `
                -Organization $Organization -Owner $Owner

            # Exec sysprep and shutdown
            C:/windows/system32/sysprep/sysprep.exe /generalize /oobe `
                /unattend:"C:/Windows/Panther/Unattend/unattend.xml" /quiet /shutdown
        }
        Default { Throw "Invalid IaaS '${IaaS}' supported platforms are: AWS, Azure, GCP and Vsphere" }
   }
}

function ModifyInfFile() {
    Param(
        [string]$InfFilePath = $(Throw "inf file path missing"),
        [string]$KeyName = $(Throw "keyname missing"),
        [string]$KeyValue = $(Throw "keyvalue missing")
    )

    $Regex = "^$KeyName"
    $TempFile = $InfFilePath + ".tmp"

    Get-Content $InfFilePath | ForEach-Object {
        $ValueToWrite=$_
        if($_ -match $Regex) {
            $ValueToWrite="$KeyName=$KeyValue"
        }
        $ValueToWrite | Out-File -Append $TempFile
    }

    Move-Item -Path $TempFile -Destination $InfFilePath -Force
}
