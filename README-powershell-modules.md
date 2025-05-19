# BOSH Powershell Modules
Powershell scripts to set up a Windows VM in a manner appropriate for a BOSH Stemcell.

## Testing

Tests are written using the Pester testing framework and must be run in Powershell on a Windows environment.

The test suite for each module currently assumes that the tests are being run with the module as the current working directory.

This requires iterating through the module directories to run all the tests:

Two copies of BOSH Powershell Modules exist in this repo:
- `stembuild/modules`
- `modules`

```powershell
# Where MODULES_DIR is ""ci/tasks/delete-vms/delete-vms.iml, or "modules"
cd $MODULES_DIR
foreach ($module in (Get-ChildItem "./modules").Name) {
  Push-Location "modules/$module"
    $results=Invoke-Pester -PassThru
    if ($results.FailedCount -gt 0) {
      $result += $results.FailedCount
    }
  Pop-Location
}
echo "Failed Tests: $result"
```

If you just need to test a single module, you could do this:

```powershell
cd "$MODULES_DIR\BOSH.<module>"
Invoke-Pester
```

## Running a subset of tests on macOS

You can use Powershell and macOS to run the tests that do not require Windows system calls:

```shell
cd ~/workspace
brew install powershell
git clone --depth 1 --branch 4.4.0 git@github.com:pester/Pester.git
pwsh
Import-Module ./Pester/Pester.psm1
cd stembuild/module/BOSH.<module>
Invoke-Pester
```
