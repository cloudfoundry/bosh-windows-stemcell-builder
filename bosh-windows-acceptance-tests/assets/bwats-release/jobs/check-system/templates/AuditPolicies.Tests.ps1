Describe "Audit Policies" {
    $expectedAuditPolicies = @{
        'Credential Validation' = 'Success and Failure';
        'Security Group Management' = 'Success';
        'User Account Management' = 'Success and Failure';
        'Plug and Play Events' = 'Success';
        'Process Creation' = 'Success';
        'Account Lockout' = 'Failure';
        'Group Membership' = 'Success';
        'Logon' = 'Success and Failure';
        'Other Logon/Logoff Events' = 'Success and Failure';
        'Special Logon' = 'Success';
        'Detailed File Share' = 'Failure';
        'File Share' = 'Success and Failure';
        'Other Object Access Events' = 'Success and Failure';
        'Removable Storage' = 'Success and Failure';
        'Audit Policy Change' = 'Success';
        'Authentication Policy Change' = 'Success';
        'MPSSVC Rule-Level Policy Change' = 'Success and Failure';
        'Other Policy Change Events' = 'Failure';
        'Sensitive Privilege Use' = 'Success and Failure';
        'Other System Events' = 'Success and Failure';
        'Security State Change' = 'Success';
        'Security System Extension' = 'Success';
        'Unknown Policy' = 'No auditing';
        'System Integrity' = 'Success and Failure';
    }

    BeforeAll {
        $backupDir = "$env:TMP/policyBackup-$([System.Guid]::NewGuid())"
        New-Item -ItemType Directory -Path $backupDir
        C:\var\vcap\packages\lgpo\lgpo\LGPO.exe /b $backupDir

        $backupPaths = (Get-ChildItem $backupDir)
        $backupPaths.length | Should Be 1

        $policyPath = "$backupDir\$($backupPaths.Name)\DomainSysvol\GPO\Machine\microsoft\windows nt\Audit\audit.csv"

        $policyPath | Should -Exist

        $actualPolicies = Import-Csv $policyPath
    }

    foreach ($policyName in $expectedAuditPolicies.keys) {
        It "audit policy '$($policyName)' is set to '$($expectedAuditPolicies[$policyName])'" {
            $expectedValue = $expectedAuditPolicies[$policyName]
            $actualPolicy = $actualPolicies | Where-Object { $_.Subcategory -eq $policyName }

            $actualPolicy | Should -Not -BeNullOrEmpty -Because "audit policy subcategory '$policyName' should exist"

            $actualPolicy.'Inclusion Setting' | Should -Be $expectedValue
        }
    }

}
