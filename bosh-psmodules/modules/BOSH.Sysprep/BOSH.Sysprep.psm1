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
                    <Path>C:\Windows\System32\cmd.exe /C C:\disable-updates.bat</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Description>Apply Group Policies</Description>
                    <Order>2</Order>
                    <Path>C:\Windows\System32\cmd.exe /C C:\bosh\lgpo\bin\apply-policies.bat</Path>
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
                    <CommandLine>C:\Windows\System32\cmd.exe /c C:\disable-updates.bat</CommandLine>
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
