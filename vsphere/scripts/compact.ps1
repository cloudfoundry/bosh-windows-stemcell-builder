try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    function Unzip
    {
        param([string]$zipfile, [string]$outpath)

        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    }

    Unzip "A:\ultradefrag.zip" "C:\Windows\Temp\"

    if (-Not (Test-Path "C:\Windows\Temp\ultradefrag-portable-7.0.1.amd64\udefrag.exe")) {
        Write-Error "compact: missing ultradefrag"
        Exit 1
    }

    C:\Windows\Temp\ultradefrag-portable-7.0.1.amd64\udefrag.exe --optimize --repeat C:
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: ultradefrag exited with code ${LASTEXITCODE}"
        Exit $LASTEXITCODE
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
    try {
       $CurFileSize = 0
        while($CurFileSize -lt $FileSize) {
            $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
            $CurFileSize +=$ZeroArray.Length
        }
    } catch {
        Write-Error "Error: zeroing volume ($Volume): ${_.Exception.Message}"
        $Success = $FALSE
    } finally {
        if($Stream) {
            $Stream.Close()
        }
        Remove-Item -Path $FilePath -Force
    }
    if (-Not $Success) {
        Exit 1
    }
} catch {
    Write-Error $_.Exception.Message
    Exit 1
}
Exit 0
