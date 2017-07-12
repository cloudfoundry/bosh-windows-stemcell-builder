#This script will allow you to run changes that start from our macOS host to the guest windows OS that will run the packer provisioning steps
#this allows us to bypass concourse when developing changes to provisioning
#run setup in install the script

function zipUpPsModules {
    $source = "C:\working_directory\stemcell-builder\bosh-psmodules\modules"
    $destination = "C:\working_directory\stemcell-builder\build\bosh-psmodules.zip"

     If(Test-path $destination) {Remove-item $destination}
    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($Source, $destination)
}

function setup {
    #you may get a warning from windows saying that some filenames are too long
    #this is ok because those files should only be a couple golang test files .
    New-Item "C:\working_directory" -type directory
    New-Item "C:\working_directory\version" -type directory
    New-Item "C:\working_directory\version\number" -type file
    New-Item "C:\working_directory\stemcell-builder\build" -type directory
    Copy-Item -Force -Recurse "Z:\workspace\greenhouse-ci\" "C:\working_directory\ci\"
    Copy-Item -Force -Recurse "Z:\workspace\bosh-windows-stemcell-builder\" "C:\working_directory\stemcell-builder\"
    Copy-Item -Force -Recurse "Z:\workspace\windows-stemcell-dependencies\" "C:\working_directory\windows-stemcell-dependencies\"
}

function killallpacker {
    taskkill /F /IM packer.exe /T
}

killallpacker

$env:ADMINISTRATOR_PASSWORD="Password123!"
$env:OS_VERSION="windows2012R2"
$env:PRODUCT_KEY="D2N9P-3P6X9-2R39C-7RTCD-MDVJX"
$env:ORGANIZATION="Pivotal_Dev"
$env:OWNER="the world"
$env:VERSION_DIR="../version"
$env:STEMCELL_DEPS_DIR="../windows-stemcell-dependencies"
$env:OUTPUT_DIR="../output_dir"

Remove-Item "C:\working_directory\output_dir" -Force -Recurse
Remove-Item "C:\working_directory\ci" -Force -Recurse
Copy-Item -Force -Recurse "Z:\workspace\greenhouse-ci\" "C:\working_directory\ci\"

Remove-Item "C:\working_directory\stemcell-builder\lib" -Force -Recurse
Remove-Item "C:\working_directory\stemcell-builder\bosh-psmodules" -Force -Recurse
Copy-Item -Force -Recurse "Z:\workspace\bosh-windows-stemcell-builder\lib\" "C:\working_directory\stemcell-builder\lib\"
Copy-Item -Force -Recurse "Z:\workspace\bosh-windows-stemcell-builder\bosh-psmodules\" "C:\working_directory\stemcell-builder\bosh-psmodules\"

zipUpPsModules

cd "\working_directory"

.\ci\bosh-windows-stemcell-builder\create-vsphere-vmdk\run.ps1

#cd "stemcell-builder"
#packer build -machine-readable -debug -on-error=abort  C:/working_directory/packer.config
