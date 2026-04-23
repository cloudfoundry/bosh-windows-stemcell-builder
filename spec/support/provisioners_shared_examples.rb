require_relative "test_provisioner"

RSpec.shared_examples "standard provisioners" do
  it "does not have nonsense provisioner" do
    nonsense_provisioner = TestProvisioner.new_powershell_provisioner("some-garbage")
    expect(provisioners).not_to include_provisioner(nonsense_provisioner), "test matcher"
  end

  it "uploads bosh ps-modules" do
    upload_bosh_ps_modules = TestProvisioner.new_file_provisioner("build/bosh-psmodules.zip", 'C:\provision\bosh-psmodules.zip')
    expect(provisioners).to include_provisioner(upload_bosh_ps_modules)
  end

  it "uploads the install-bosh-psmodules script" do
    upload_install_bosh_ps_modules = TestProvisioner.new_file_provisioner(
      "scripts/install-bosh-psmodules.ps1",
      'C:\provision\install-bosh-psmodules.ps1'
    )
    expect(provisioners).to include_provisioner(upload_install_bosh_ps_modules)
  end

  it "runs install bosh ps modules after uploading zip file and install script" do
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')
    upload_modules = TestProvisioner.new_file_provisioner("build/bosh-psmodules.zip", 'C:\provision\bosh-psmodules.zip')
    upload_install_modules = TestProvisioner.new_file_provisioner(
      "scripts/install-bosh-psmodules.ps1",
      'C:\provision\install-bosh-psmodules.ps1'
    )

    expect(provisioners).to include_provisioner(install_modules_provisioner, after: [upload_install_modules, upload_modules])
  end

  it "runs get-hotfix after windows updates are applied" do
    get_hotfix_prov = TestProvisioner.new_powershell_provisioner("Get-HotFix | Out-File -FilePath hotfixes.log -Encoding utf8")
    wait_windows_update_prov = TestProvisioner.new_powershell_provisioner(/Wait-WindowsUpdates -Password .+ -User Provisioner/)
    expect(provisioners).to include_provisioner(get_hotfix_prov, after: [wait_windows_update_prov])
    # expect(provisioners).to include_provisioner(get_hotfix_prov)

    prov_index = provisioners.find_index do |p|
      p["type"] == "powershell" && p.has_key?("inline") && p["inline"].include?("Get-HotFix | Out-File -FilePath hotfixes.log -Encoding utf8")
    end
    expect(prov_index).not_to be_nil, "Could not find Get-Hotfix provisioner"

    hotfixes_applied_index = provisioners.find_index do |p|
      p["type"] == "powershell" && p.has_key?("inline") && p["inline"].include?("Register-WindowsUpdatesTask")
    end

    unregister_windows_index = provisioners.find_index do |p|
      p["type"] == "powershell" && p.has_key?("inline") && p["inline"].include?("Unregister-WindowsUpdatesTask")
    end

    expect(prov_index).to be > hotfixes_applied_index, "Print Hotfix provisioner not after Windows-Updates"
    expect(prov_index).to be > unregister_windows_index, "Print Hotfix provisioner not after Unregister Windows-Updates"
  end

  it "runs Unregister windows update after the post-RegisterWindowsUpdates windows-restart" do
    register_windows_updates_task_provisioner = TestProvisioner.new_powershell_provisioner("Register-WindowsUpdatesTask")
    expect(provisioners).to include_provisioner(register_windows_updates_task_provisioner), "test matcher"

    # noinspection RubyInterpreter
    register_updates_index = provisioners.find_index do |p|
      p["type"] == "powershell" && p.has_key?("inline") && p["inline"].include?("Register-WindowsUpdatesTask")
    end
    expect(register_updates_index).not_to be_nil, "Could not find RegisterWindowsUpdates provisioner"

    post_register_provisioners = provisioners[(register_updates_index + 1)..]

    prov_index = post_register_provisioners.find_index do |p|
      provisioner_command = "Unregister-WindowsUpdatesTask"
      # TODO extract this and equivalent lines out into function
      p["type"] == "powershell" && p.has_key?("inline") && p["inline"].include?(provisioner_command)
    end
    expect(prov_index).not_to be_nil, "Could not find Unregister-WindowsUpdatesTask provisioner"

    windows_restart_index = post_register_provisioners.find_index do |p|
      p["type"] == "windows-restart"
    end

    expect(prov_index).to be > windows_restart_index, "UnregisterWindowsUpdates not before windows-restart"
  end

  it "runs Internet Explorer related registry changes after install-bosh-psmodules is run" do
    internet_explorer_provisioner = TestProvisioner.new_powershell_provisioner("Set-InternetExplorerRegistries")
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')

    expect(provisioners).to include_provisioner(internet_explorer_provisioner, after: [install_modules_provisioner])
  end

  it "runs Set-InternetExplorerRegistries before Invoke-Sysprep is run" do
    invoke_sysprep_provisioner = TestProvisioner.new_powershell_provisioner(/Invoke-Sysprep -IaaS #{iaas_name}/)
    internet_explorer_provisioner = TestProvisioner.new_powershell_provisioner("Set-InternetExplorerRegistries")

    expect(provisioners).to include_provisioner(invoke_sysprep_provisioner, after: [internet_explorer_provisioner])
  end
end
