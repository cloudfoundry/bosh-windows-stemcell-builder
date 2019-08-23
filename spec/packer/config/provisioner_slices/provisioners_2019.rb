require 'rspec/expectations'
require './spec/packer/config/provisioner_slices/test_provisioner'

shared_examples "a 2019 provisioner" do |provisioner_config|
  let(:provisioners) {provisioner_config.provisioners}

  it 'runs Internet Explorer related registry changes after install-bosh-psmodules is run' do
    internet_explorer_provisioner = TestProvisioner.new_powershell_provisioner("Set-InternetExplorerRegistries")
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')

    expect(provisioners).to include_provisioner(internet_explorer_provisioner, after: [install_modules_provisioner])
  end
end