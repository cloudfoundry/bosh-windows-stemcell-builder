Write-Host "I am executing a simple bosh errand"
Get-ChildItem

$logPath = "/var/vcap/sys/log/errand"
New-Item -ItemType Directory -Force -Path  $logPath

$unixTimestamp = ([int][double]::Parse((Get-Date -UFormat %s)))
wmic qfe list brief /format:texttablewsys > "$logPath/update-list-$unixTimestamp.txt"
