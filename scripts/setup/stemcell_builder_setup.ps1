################################################
#  / __\   _ _ __   ___| |_(_) ___  _ __  ___  #
# / _\| | | | '_ \ / __| __| |/ _ \| '_ \/ __| #
#/ /  | |_| | | | | (__| |_| | (_) | | | \__ \ #
#\/    \__,_|_| |_|\___|\__|_|\___/|_| |_|___/ #
################################################
function Download-File {
param (
  [string]$url,
  [string]$file
 )

   $uri = New-Object "System.Uri" "$url"

   $request = [System.Net.HttpWebRequest]::Create($uri)

   $request.set_Timeout(15000) #15 second timeout

   $response = $request.GetResponse()

   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)

   $responseStream = $response.GetResponseStream()

   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $file, Create

   $buffer = new-object byte[] 10KB

   $count = $responseStream.Read($buffer,0,$buffer.length)

   $downloadedBytes = $count

   while ($count -gt 0)

   {

       $targetStream.Write($buffer, 0, $count)

       $count = $responseStream.Read($buffer,0,$buffer.length)

       $downloadedBytes = $downloadedBytes + $count

       Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)

   }
   Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"

   $targetStream.Flush()

   $targetStream.Close()

   $targetStream.Dispose()

   $responseStream.Dispose()

}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function Add-Path
{
    param([string]$path)
    [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path",[System.EnvironmentVariableTarget]::Machine) + ";" + $path, [System.EnvironmentVariableTarget]::Machine)
}

##############################################################################################
#  _____            _                                      _     ____       _                #
# | ____|_ ____   _(_)_ __ ___  _ __  _ __ ___   ___ _ __ | |_  / ___|  ___| |_ _   _ _ __   #
# |  _| | '_ \ \ / / | '__/ _ \| '_ \| '_ ` _ \ / _ \ '_ \| __| \___ \ / _ \ __| | | | '_ \  #
# | |___| | | \ V /| | | | (_) | | | | | | | | |  __/ | | | |_   ___) |  __/ |_| |_| | |_) | #
# |_____|_| |_|\_/ |_|_|  \___/|_| |_|_| |_| |_|\___|_| |_|\__| |____/ \___|\__|\__,_| .__/  #
#                                                                                    |_|     #
##############################################################################################

Set-ExecutionPolicy Bypass
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Host "Golang"
choco install golang -y
Add-Path -path "C:\tools\go\bin"

Write-Host "ruby"
choco install ruby --version 2.3.3 -y
Add-Path -path "C:\tools\ruby23\bin"

Write-Host "workstation"
choco install vmwareworkstation -y

Write-Host "ovf tool"
$ovftool="C:\Program Files (x86)\VMware\VMware Workstation\OVFTool"
Add-Path -path $ovftool

Write-Host "bin folder"
New-Item -ItemType directory -Path C:\bin -Force
Add-Path -path "C:\bin"

Write-Host "bin\tar"
Download-File -url "https://s3.amazonaws.com/bosh-windows-dependencies/tar-1490035387.exe" -file "C:\bin\tar.exe"

Write-Host "bin\packer"
Download-File -url "https://github.com/greenhouse-org/packer/releases/download/stemcell-builder-1.0.0/packer_windows_amd64.zip" -file "C:\bin\packer_windows.zip"
Unzip -zipfile "C:\bin\packer_windows.zip" -outpath "C:\bin\"
Move-Item -Path "C:\bin\packer_windows_amd64\packer.exe"-Destination "C:\bin\packer.exe"

Write-Host "reload environemnt"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "bundler (sometimes this takes a few minutes)"
gem install bundler -V

Write-Host "testing installation"
$RequiredExes=@(
    "tar.exe",
    "packer.exe",
    "ovftool.exe",
    "go.exe",
    "ruby.exe"
)
foreach ($exe in $RequiredExes) {
    Get-Command $exe
}
