$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

    Remove-Item -Path $zipfile -Force
}

$UltradefragZip = "C:\ultradefrag.zip"
$UltradefragBinary = "ultradefrag-portable-7.0.1.amd64\udefrag.exe"

if (-Not (Test-Path $UltradefragZip)) {
    Write-Error "compact: missing dependency: ${UltradefragZip}"
}

Unzip $UltradefragZip "C:\Windows\Temp\"

if (-Not (Test-Path "C:\Windows\Temp\ultradefrag-portable-7.0.1.amd64\udefrag.exe")) {
    Write-Error "compact: missing ultradefrag"
}

C:\Windows\Temp\ultradefrag-portable-7.0.1.amd64\udefrag.exe --optimize --repeat C:
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: ultradefrag exited with code ${LASTEXITCODE}"
}

$Success = $TRUE
$FilePath="c:\zero.tmp"
$Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
$ArraySize= 64kb
$SpaceToLeave= $Volume.Size * 0.05
$FileSize= $Volume.FreeSpace - $SpacetoLeave
$ZeroArray= New-Object byte[]($ArraySize)

Write-Host "Zeroing volume: $Volume"
$Stream= [io.File]::OpenWrite($FilePath)
$CurFileSize = 0
while($CurFileSize -lt $FileSize) {
    $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
    $CurFileSize +=$ZeroArray.Length
}
if($Stream) {
    $Stream.Close()
}
Remove-Item -Path $FilePath -Force

Exit 0
