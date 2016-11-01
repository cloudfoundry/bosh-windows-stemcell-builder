Add-Type -AssemblyName System.IO.Compression.FileSystem
  function Unzip
  {
      param([string]$zipfile, [string]$outpath)

      [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

      rm $zipfile
  }

Invoke-WebRequest "https://msdnshared.blob.core.windows.net/media/2016/09/LGPOv2-PRE-RELEASE.zip" -OutFile "C:\bosh\lgpov2.zip"
Unzip "C:\bosh\lgpov2.zip" "C:\var\vcap\bosh\bin\"
C:\var\vcap\bosh\bin\LGPO.exe /g A:\policy-baselines
