$ec2config = [xml] (get-content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml')
($ec2config.ec2configurationsettings.plugins.plugin | where {$_.name -eq "Ec2SetPassword"}).state = 'Enabled'
$ec2config.save("C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml")
