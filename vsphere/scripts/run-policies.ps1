Add-Type -AssemblyName System.IO.Compression.FileSystem
  function Unzip
  {
      param([string]$zipfile, [string]$outpath)

      [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

      rm $zipfile
  }

Push-Location $env:TEMP
Invoke-WebRequest "https://msdnshared.blob.core.windows.net/media/2016/09/LGPOv2-PRE-RELEASE.zip" -OutFile "lgpov2.zip"
Unzip "lgpov2.zip" "${env:TEMP}"
.\LGPO.exe /g A:\policy-baselines
Pop-Location
