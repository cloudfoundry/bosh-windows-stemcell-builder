$Error.Clear()

Configuration WindowsFeatures {
  Node "localhost" {

    WindowsFeature IISWebServer {
      Ensure = "Present"
        Name = "Web-Webserver"
    }
    WindowsFeature WebSockets {
      Ensure = "Present"
        Name = "Web-WebSockets"
    }
    WindowsFeature WebServerSupport {
      Ensure = "Present"
        Name = "AS-Web-Support"
    }
    WindowsFeature DotNet {
      Ensure = "Present"
        Name = "AS-NET-Framework"
    }
    WindowsFeature HostableWebCore {
      Ensure = "Present"
        Name = "Web-WHC"
    }

    WindowsFeature ASPClassic {
      Ensure = "Present"
      Name = "Web-ASP"
    }
  }
}

if($PSVersionTable.PSVersion.Major -lt 4) {
  $shell = New-Object -ComObject Wscript.Shell
  $shell.Popup("You must be running Powershell version 4 or greater", 5, "Invalid Powershell version", 0x30)
  echo "You must be running Powershell version 4 or greater"
  exit(-1)
}

Install-WindowsFeature DSC-Service
WindowsFeatures
Start-DscConfiguration -Wait -Path .\WindowsFeatures -Force -Verbose

if ($Error) {
    Write-Host "Error summary:"
    foreach($ErrorMessage in $Error)
    {
      Write-Host $ErrorMessage
    }
}
