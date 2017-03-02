$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

$DEST = "C:\bosh\lgpo"
if(!(Test-Path -Path $DEST )){
  mkdir $DEST
}
$BIN = "C:\bosh\lgpo\bin"
if(!(Test-Path -Path $BIN )){
  mkdir $BIN
}
$env:PATH="${env:PATH};$BIN"
Move-Item -Path "C:\LGPO.exe" -Destination "$BIN\LGPO.exe"

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
  param([string]$zipfile, [string]$outpath)

  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

  rm $zipfile
}

Unzip "C:\policy-baseline.zip" $DEST
if (-Not (Test-Path "$DEST\policy-baseline")) {
  Write-Error "ERROR: could not extract policy-baseline"
}

echo "$BIN\LGPO.exe /g $DEST\policy-baseline /v 2>&1 > $DEST\LGPO.log" | Out-File -Encoding ASCII "$BIN\apply-policies.bat"

Exit 0
