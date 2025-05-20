# BOSH Powershell Modules
Powershell scripts to set up a Windows VM in a manner appropriate for a BOSH Stemcell.

## Testing

Tests are written using the Pester testing framework and must be run in Powershell on a Windows environment.

The test suite for each module currently assumes that the tests are being run with the module as the current working directory.

This requires iterating through the module directories to run all the tests:

```powershell
# Where MODULES_DIR is "stembuild/modules", or "modules"
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
# Where MODULES_DIR is "stembuild/modules", or "modules"
cd "$MODULES_DIR\BOSH.<module>"
Invoke-Pester
```


### Running tests via Concourse

```shell
# Where MODULES_DIR is "stembuild/modules", or "modules"
cd bosh-windows-stemcell-builder 
fly -t bosh-ecosystem execute \
    --tag=windows-nimbus \
    --config "./ci/tasks/test-units-bosh-psmodules/task.yml" \
    --inputs-from=windows-2019-stemcell/test-bosh-psmodules \
    --input=stemcell-builder="./"
```

### Running a subset of tests on macOS

You can use Powershell and macOS to run the tests that do not require Windows system calls:

```shell
cd ~/workspace
brew install powershell
git clone --depth 1 git@github.com:pester/Pester.git
pwsh
Import-Module ./Pester/Pester.psm1
cd stembuild/module/BOSH.<module>
Invoke-Pester
```

## Debugging

You can debug powershell scripts using VSCode. It has some dependencies:
- dotnet runtime `brew install dotnet`
- powershell binary `brew install powershell`
- vscode extensions: `Powershell`, `C#` and `C# Dev Kit` (the latter may not be required)

You can create a launch.json file like:
```json
{
    "version": "0.2.0",
    "configurations": [

        {
            "name": "PowerShell: Run Pester Tests",
            "type": "PowerShell",
            "request": "launch",
            "script": "Invoke-Pester",
            "createTemporaryIntegratedConsole": true,
            "attachDotnetDebugger": true,
            "cwd": "${file}"
        }
    ]
}
```

And you should be able to run tests for a single file using the debug view. If you're missing extensions
you'll see odd failures such as the wrong CWD leading to import failures.