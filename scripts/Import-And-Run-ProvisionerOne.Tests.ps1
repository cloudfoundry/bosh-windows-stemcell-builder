Describe "Import-And-Run-ProvisionerOne.Tests.ps1" {
    BeforeEach {
        function Set-ProxySettings
        {
            param ([string]$HTTPProxy, [string]$HTTPSProxy)
        }
    }
    It "unzips bosh-psmodules" {
        Mock Expand-Archive { }
        .\Import-And-Run-ProvisionerOne.ps1
        $outPath = "C:\Program Files\WindowsPowerShell\Modules"
        Assert-MockCalled Expand-Archive -Times 1 -Scope It -ParameterFilter {
            $Path -eq "C:\provision\bosh-psmodules.zip" -and $DestinationPath -eq $outPath
        }
    }

    Context "when proxy settings are passed" {
        It "sets proxy settings" {
            Mock Set-ProxySettings { }
            $proxySetFlags = "-HTTPProxy my.proxy"# -HTTPSProxy secure.proxy"
            .\Import-And-Run-ProvisionerOne.ps1 $proxySetFlags
            Assert-MockCalled Set-ProxySettings -Times 1 -Scope It -ParameterFilter {
                Write-Host $HTTPProxy
                $HTTPProxy -eq "my.proxy"
            }
        }
    }
}
