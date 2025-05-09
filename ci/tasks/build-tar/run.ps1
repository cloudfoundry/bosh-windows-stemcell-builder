$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

# remove sh.exe from $env:PATH
$env:PATH = ($env:PATH.Split(';') | Where-Object { $_ -ne 'c:\var\vcap\packages\git\bin' }) -join ';'
$env:PATH = ($env:PATH.Split(';') | Where-Object { $_ -ne 'C:\var\vcap\packages\msys2\usr\bin' }) -join ';'

bsdtar/install.ps1
Exit $LastExitCode
