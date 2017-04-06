<#
.Synopsis
    Sysprep Utilities
.Description
    This cmdlet enables enabling a local security policy for a stemcell
#>
function Enable-LocalSecurityPolicy {
    Param (
      [string]$LgpoExe ="C:\windows\lgpo.exe",
      [string]$PolicyDestination = "C:\bosh\lgpo"
    )

    Write-Log "Starting LocalSecurityPolicy"

    New-Item -Path "$PolicyDestination" -ItemType Directory -Force
    $policyZipFile = Join-Path $PSScriptRoot "policy-baseline.zip"
    Open-Zip -ZipFile $policyZipFile -OutPath $PolicyDestination
    if (-Not (Test-Path "$PolicyDestination\policy-baseline")) {
	Write-Error "ERROR: could not extract policy-baseline"
    }

    Invoke-Expression "$LgpoExe /g $PolicyDestination\policy-baseline /v 2>&1 > $PolicyDestination\LGPO.log"
    if ($LASTEXITCODE -ne 0) {
	Throw "lgpo.exe exited with $LASTEXITCODE"
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

   Write-Log "Starting Create-Unattend"

   New-Item -ItemType directory $UnattendDestination -Force
   $UnattendPath = Join-Path $UnattendDestination "unattend.xml"

   Write-Log "Writing unattend.xml to $UnattendPath"

   $ProductKeyXML="<RegisteredOwner />"
   if ($ProductKey -ne "") {
      if ($Organization -eq "" -or $Owner -eq "") {
         Throw "Provide an Organization and Owner"
      }
      $ProductKeyXML="<ProductKey>$ProductKey</ProductKey>
      <RegisteredOrganization>$Organization</RegisteredOrganization>
      <RegisteredOwner>$Owner</RegisteredOwner>"
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
        </component>
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Description>Disable Windows Updates</Description>
                    <Order>1</Order>
                    <Path>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command Disable-AutomaticUpdates</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Description>Apply Group Policies</Description>
                    <Order>2</Order>
                    <Path>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command Enable-LocalSecurityPolicy</Path>
                    <WillReboot>Always</WillReboot>
                </RunSynchronousCommand>
            </RunSynchronous>
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
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
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
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command Disable-AutomaticUpdates</CommandLine>
                    <Order>1</Order>
                    <Description>Disable Windows Updates</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
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
                    <PlainText>true</PlainText>
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
      [string]$Owner=""
   )

   Write-Log "Invoking Sysprep for IaaS: ${IaaS}"

   switch ($IaaS) {
      "aws" {
         # Enable password generation and retrieval
         $ec2config = [xml] (get-content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml')
         ($ec2config.ec2configurationsettings.plugins.plugin | where { $_.Name -eq "Ec2SetPassword" }).State = 'Enabled'
         $ec2config.Save("C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml")

         # Enable sysprep
         $ec2settings = [xml] (get-content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\BundleConfig.xml')
         ($ec2settings.BundleConfig.Property | where { $_.Name -eq "AutoSysprep" }).Value = 'Yes'
         $ec2settings.Save('C:\Program Files\Amazon\Ec2ConfigService\Settings\BundleConfig.xml')
      }
      "gcp" {
         GCESysprep
      }
      "azure" {
         C:\Windows\System32\Sysprep\sysprep.exe /generalize /quiet /oobe /quit
      }
      "vsphere" {
         Create-Unattend -NewPassword $NewPassword -ProductKey $ProductKey -Organization $Organization -Owner $Owner
         C:/windows/system32/sysprep/sysprep.exe /generalize /oobe /unattend:"C:/Windows/Panther/Unattend/unattend.xml" /quiet /shutdown
      }
      Default { Throw "Invalid IaaS '${IaaS}' supported platforms are: AWS, Azure, GCP and Vsphere" }
   }
}
