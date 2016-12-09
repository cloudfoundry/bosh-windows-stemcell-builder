$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

$BOSH_BIN="C:\\var\\vcap\\bosh\\bin"
Write-Host "Checking $BOSH_BIN dependencies"

$files = New-Object System.Collections.ArrayList
[void] $files.AddRange(("bosh-blobstore-s3.exe", "bosh-blobstore-dav.exe", "tar.exe", "zlib1.dll", "job-service-wrapper.exe"))

Get-ChildItem $BOSH_BIN | ForEach-Object {
  Write-Host "Checking for $_.Name"
  $files.remove($_.Name)
}

If ($files.Count -gt 0) {
  Write-Error "Unable to find the following binaries: $($files -join ',')"
}
