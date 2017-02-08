$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

# no exit code - this runs silently in the background.
# checking LASTEXITCODE -ne 0 will error.
C:\VMware-tools.exe /S /v "/qn REBOOT=R"
