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

  Invoke-WebRequest "https://msdnshared.blob.core.windows.net/media/TNBlogsFS/prod.evol.blogs.technet.com/telligent.evolution.components.attachments/01/4062/00/00/03/65/94/11/LGPO.zip" -OutFile "C:\bosh\lgpo.zip"
  if (-Not (Test-Path "C:\bosh\lgpo.zip")) {
    Write-Error "ERROR: could not download LGPO"
    Exit 1
  }

  Unzip "C:\bosh\lgpo.zip" "C:\var\vcap\bosh\bin\"
  if (-Not (Test-Path "C:\var\vcap\bosh\bin\LGPO.exe")) {
    Write-Error "ERROR: could not extract LGPO"
    Exit 1
  }

  Unzip "A:\policy-baseline.zip" "C:\bosh\"
  if (-Not (Test-Path "C:\bosh\policy-baseline")) {
    Write-Error "ERROR: could not extract policy-baseline"
    Exit 1
  }

  C:\var\vcap\bosh\bin\LGPO.exe /g C:\bosh\policy-baseline /v 2>&1 > C:\var\vcap\bosh\LGPO.log
  if ($LASTEXITCODE -ne 0) {
    Write-Host $(Get-Content C:\var\vcap\bosh\LGPO.log)
    Write-Error "Error: LGPO exited with code ${LASTEXITCODE}"
    Exit $LASTEXITCODE
  }
  Write-Host $(Get-Content C:\var\vcap\bosh\LGPO.log)

} catch {
  Write-Error $_.Exception.Message
  Exit 1
}
Exit 0
