function LogWrite {
   Param ([string]$LogFile, [string]$Message)

   $msg = "{0} {1}" -f (Get-Date -Format o), $Message
   Add-Content -Path $LogFile -Value $msg -Encoding 'UTF8'
   Write-Host $msg
}

function Unzip {
    param([string]$ZipFile, [string]$OutPath, [Switch]$Keep)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)

    if (!$Keep) {
        Write-Host "Unzip: removing zipfile ${ZipFile}"
        Remove-Item -Path $ZipFile -Force
    }
}

Export-ModuleMember -Function LogWrite
Export-ModuleMember -Function Unzip
