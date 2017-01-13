$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

# To find the latest VMware-tools.exe for ESXi 6.0 see:
# https://packages.vmware.com/tools/esx/6.0latest/windows/x64/index.html

$toolsURL="https://packages.vmware.com/tools/esx/6.0latest/windows/x64/VMware-tools-10.0.9-3917699-x86_64.exe"

if (Test-Path "C:\Windows\Temp\VMware-tools.exe") {
    Remove-Item -Force -Path "C:\Windows\Temp\VMware-tools.exe"
}

(New-Object System.Net.WebClient).DownloadFile($toolsURL, "C:\Windows\Temp\VMware-tools.exe")

# no exit code - this runs silently in the background.
# checking LASTEXITCODE -ne 0 will error.
C:\Windows\Temp\VMware-tools.exe /S /v "/qn REBOOT=R"
