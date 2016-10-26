$logPath = "/var/vcap/sys/log/errand"
New-Item -ItemType Directory -Force -Path  $logPath

$unixTimestamp = ([int][double]::Parse((Get-Date -UFormat %s)))
wmic qfe list brief /format:csv | ? {$_.trim() -ne "" } > "$logPath/update-list-$unixTimestamp.csv"
