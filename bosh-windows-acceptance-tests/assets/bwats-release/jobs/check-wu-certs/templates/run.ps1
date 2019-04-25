$ErrorActionPreference = "Stop"
trap { $host.SetShouldExit(1) }

function NonTerminatingError() {
  Param(
    [Parameter(Mandatory=$True)]
    [string]$Message
  )

  $ErrorActionPreference = "Continue"
  Write-Error $Message
  $ErrorActionPreference = "Stop"
}

certutil -generateSSTFromWU wucerts.sst

$currentCert = ""
$expectedCerts = @()
certutil -dump wucerts.sst | ForEach-Object {
    if ($_ -match "==== Certificate") {
        if ($currentCert -ne "") {
            $expectedCerts += $currentCert
        }
        $currentCert = $_
    } elseif ($_ -match "CertUtil: -dump command completed") {
        $expectedCerts += $currentCert
   } else {
        $currentCert += [Environment]::NewLine
        $currentCert += $_
   }
}

$systemCertThumbprints = Get-ChildItem Cert:/ -Recurse | ForEach-Object {
    $_.Thumbprint
}

$failed = $False
$expectedCerts | ForEach-Object {
    $expectedCertThumbprint = ($_ | findstr /R /C:"Cert Hash(sha1)").split(" ")[2]

    if ($systemCertThumbprints -notcontains $expectedCertThumbprint) {
        $failed = $True
        NonTerminatingError "Expected to find the following certificate in the system certificates, but didn't: $_"
    }
}

if ($failed) {
    Write-Error "Some certificates found on the Windows Update server were not present on the host"
}
