function Set-TmpDir
{
    $working_directory = Get-Location
    $guid = $( New-Guid ).Guid
    $temp_directory=Join-Path -Path $working_directory.path -ChildPath "temp-$guid"
    New-Item -Path $temp_directory -ItemType Directory
    $env:TMP=$temp_directory
    $env:SystemTemp=$temp_directory
}

function Set-VCenterHostAndCert
{
    $request = [System.Net.HttpWebRequest]::Create("https://$env:VCENTER_BASE_URL")
    try { $request.GetResponse().Dispose() } catch {}

    $ca_cert=new-object System.Text.StringBuilder
    $ca_cert.AppendLine("-----BEGIN CERTIFICATE-----")
    $ca_cert.AppendLine([System.Convert]::ToBase64String($request.ServicePoint.Certificate.GetRawCertData(), 1))
    $ca_cert.AppendLine("-----END CERTIFICATE-----")
    $env:VCENTER_CA_CERT=$ca_cert.ToString()

    $base_url=$request.ServicePoint.Certificate.Subject.Split("=").Get(2)

    # We use an additional dns redirect that will cause TLS to fail
    # So we fetch the hostname we're supposed to be using from the Cert
    if (Test-Path 'env:VCENTER_ADMIN_CREDENTIAL_URL') {
      $env:VCENTER_ADMIN_CREDENTIAL_URL=$env:VCENTER_ADMIN_CREDENTIAL_URL.replace($env:VCENTER_BASE_URL, $base_url)
    }
    $env:VCENTER_BASE_URL=$base_url
}
