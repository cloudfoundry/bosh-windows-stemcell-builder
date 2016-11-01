try {
  if(!(Test-Path -Path "C:\bosh" )){
    mkdir "C:\bosh"
  }
  if(!(Test-Path -Path "C:\var\vcap\bosh\bin" )){
    mkdir "C:\var\vcap\bosh\bin"
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  function Unzip
  {
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

    rm $zipfile
  }

  Invoke-WebRequest "https://msdnshared.blob.core.windows.net/media/2016/09/LGPOv2-PRE-RELEASE.zip" -OutFile "C:\bosh\lgpov2.zip"
  if (-Not (Test-Path "C:\bosh\lgpov2.zip")) {
    Write-Error "ERROR: could not download LGPO"
    Exit 1
  }

  Unzip "C:\bosh\lgpov2.zip" "C:\var\vcap\bosh\bin\"
  if (-Not (Test-Path "C:\var\vcap\bosh\bin\LGPO.exe")) {
    Write-Error "ERROR: could not extract LGPO"
    Exit 1
  }

  Unzip "A:\policy-baseline.zip" "C:\bosh\"
  if (-Not (Test-Path "C:\bosh\policy-baseline")) {
    Write-Error "ERROR: could not extract policy-baseline"
    Exit 1
  }

  C:\var\vcap\bosh\bin\LGPO.exe /g C:\bosh\policy-baseline
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: LGPO exited with code ${LASTEXITCODE}"
    Exit $LASTEXITCODE
  }
} catch {
  Write-Error $_.Exception.Message
  Exit 1
}
Exit 0
