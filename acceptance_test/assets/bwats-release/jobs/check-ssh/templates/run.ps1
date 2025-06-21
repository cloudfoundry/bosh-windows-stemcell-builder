$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

$success = $True

$boshUsers = (NET.EXE USER) -Split '\s+' | Where {$_ -Like 'bosh_*'}
if ($boshUsers -ne $null) {
    if ($boshUsers -Is [System.String]) {
        # Singular, alternative is a collection
        Write-Error "Expected not to find any bosh users, however the user $boshUsers exists"
    } else {
        # Plural
        Write-Error "Expected not to find any bosh users, however the following users exist: $($boshUsers -Join ', ')"
    }
    $success = $False
}

$unexpectedFiles = Get-Childitem C:\Users\bosh_* | `
    foreach { Get-ChildItem -Force -Recurse -Attributes !Directory -Exclude 'ntuser.dat*', 'usrclass.dat*' $_ }

if ($unexpectedFiles -ne $null) {
    Write-Error "Expect to only find certain registry files associated with bosh users on file system, instead found $(($unexpectedFiles | Measure-Object).Count) other file(s)"
    $success = $False
}

if (!$success) {
    Exit 1
}
