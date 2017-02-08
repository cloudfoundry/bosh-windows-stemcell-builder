Get-ChildItem -Path C:\Windows\Temp |
    Select-Object -expandproperty fullname |
    Where { $_ -notlike "C:\Windows\Temp\vm*" } |
    Remove-Item -Force -Recurse
