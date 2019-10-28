$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

install-bosh-psmodules.ps1