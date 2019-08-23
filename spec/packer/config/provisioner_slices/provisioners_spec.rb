require 'rspec/expectations'
require './spec/packer/config/provisioner_slices/provisioner_matcher'
require './spec/packer/config/provisioner_slices/test_provisioner'
require './spec/packer/config/provisioner_slices/provisioners_2019'

shared_examples "a standard provisioner" do |provisioner_config|
  let(:provisioners) {provisioner_config.provisioners}

  it 'does not have nonsense provisioner' do
    nonsense_provisioner = TestProvisioner.new_powershell_provisioner('some-garbage')
    expect(provisioners).not_to include_provisioner(nonsense_provisioner), 'test matcher'
  end

  it 'uploads bosh ps-modules' do
    upload_bosh_ps_modules = TestProvisioner.new_file_provisioner('build/bosh-psmodules.zip', 'C:\provision\bosh-psmodules.zip')
    expect(provisioners).to include_provisioner(upload_bosh_ps_modules)
  end

  it 'uploads the install-bosh-psmodules script' do
    upload_install_bosh_ps_modules = TestProvisioner.new_file_provisioner(
        'scripts/install-bosh-psmodules.ps1',
        'C:\provision\install-bosh-psmodules.ps1'
    )
    expect(provisioners).to include_provisioner(upload_install_bosh_ps_modules)
  end

  it 'runs install bosh ps modules after uploading zip file and install script' do
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')
    upload_modules = TestProvisioner.new_file_provisioner('build/bosh-psmodules.zip', 'C:\provision\bosh-psmodules.zip')
    upload_install_modules = TestProvisioner.new_file_provisioner(
        'scripts/install-bosh-psmodules.ps1',
        'C:\provision\install-bosh-psmodules.ps1'
    )

    expect(provisioners).to include_provisioner(install_modules_provisioner, after: [upload_install_modules, upload_modules])
  end

  it 'runs get-hotfix after windows updates are applied' do
    get_hotfix_prov = TestProvisioner.new_powershell_provisioner('Get-HotFix > hotfixes.log')
    wait_windows_update_prov = TestProvisioner.new_powershell_provisioner(/Wait-WindowsUpdates -Password .+ -User Provisioner/)
    expect(provisioners).to include_provisioner(get_hotfix_prov, after: [wait_windows_update_prov])
    # expect(provisioners).to include_provisioner(get_hotfix_prov)

    prov_index = provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Get-HotFix > hotfixes.log')
    end
    expect(prov_index).not_to be_nil, 'Could not find Get-Hotfix provisioner'


    hotfixes_applied_index = provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Register-WindowsUpdatesTask')
    end

    unregister_windows_index = provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Unregister-WindowsUpdatesTask')
    end

    expect(prov_index).to be > hotfixes_applied_index, 'Print Hotfix provisioner not after Windows-Updates'
    expect(prov_index).to be > unregister_windows_index, 'Print Hotfix provisioner not after Unregister Windows-Updates'
  end

  it 'runs Unregister windows update after the post-RegisterWindowsUpdates windows-restart' do
    register_windows_updates_task_provisioner = TestProvisioner.new_powershell_provisioner('Register-WindowsUpdatesTask')
    expect(provisioners).to include_provisioner(register_windows_updates_task_provisioner), 'test matcher'


    # noinspection RubyInterpreter
    register_updates_index = provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Register-WindowsUpdatesTask')
    end
    expect(register_updates_index).not_to be_nil, 'Could not find RegisterWindowsUpdates provisioner'

    post_register_provisioners = provisioners[(register_updates_index + 1)..-1]

    prov_index = post_register_provisioners.find_index do |p|
      provisionerCommand = 'Unregister-WindowsUpdatesTask'
      #TODO extract this and equivalent lines out into function
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?(provisionerCommand)
    end
    expect(prov_index).not_to be_nil, 'Could not find Unregister-WindowsUpdatesTask provisioner'

    windows_restart_index = post_register_provisioners.find_index do |p|
      p['type'] == 'windows-restart'
    end

    expect(prov_index).to be > windows_restart_index, 'UnregisterWindowsUpdates not before windows-restart'
  end
end

describe 'provisioners' do
  before(:context) do
    @stemcell_deps_dir = Dir.mktmpdir('gcp')
    ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir
  end

  after(:context) do
    FileUtils.rm_rf(@stemcell_deps_dir)
    ENV.delete('STEMCELL_DEPS_DIR')
  end

  context 'aws' do
    standard_options = {
        aws_access_key: '',
        aws_secret_key: '',
        region: '',
        output_directory: 'some-output-directory',
        version: '',
    }

    context '2012R2' do
      it_behaves_like "a standard provisioner", Packer::Config::Aws.new(
          standard_options.merge(os: 'windows2012R2')
      )
    end

    context '1803' do
      it_behaves_like "a standard provisioner", Packer::Config::Aws.new(
          standard_options.merge(os: 'windows1803')
      )
    end

    context '2019' do
      packer_config_aws_2019 = Packer::Config::Aws.new(
          standard_options.merge(os: 'windows2019')
      )
      it_behaves_like "a standard provisioner", packer_config_aws_2019

      it_behaves_like "a 2019 provisioner", packer_config_aws_2019

      it 'runs Set-InternetExplorerRegistries before Invoke-Sysprep is run' do
        invoke_sysprep_provisioner = TestProvisioner.new_powershell_provisioner(/Invoke-Sysprep -IaaS aws/)
        internet_explorer_provisioner = TestProvisioner.new_powershell_provisioner("Set-InternetExplorerRegistries")

        expect(packer_config_aws_2019.provisioners).to include_provisioner(invoke_sysprep_provisioner, after: [internet_explorer_provisioner])
      end
    end
  end

  context 'vsphere' do
    standard_options = {
        output_directory: 'output_directory',
        num_vcpus: 1,
        mem_size: 1000,
        product_key: 'key',
        organization: 'me',
        owner: 'me',
        administrator_password: 'password',
        source_path: 'source_path',
        version: '',
        enable_rdp: false,
        new_password: 'new-password',
        http_proxy: nil,
        https_proxy: nil,
        bypass_list: nil,
    }

    context '2012R2' do
      it_behaves_like 'a standard provisioner', Packer::Config::VSphere.new(
          standard_options.merge(os: 'windows2012R2')
      )
    end

    context '2019' do
      packer_config_vsphere_2019 = Packer::Config::VSphere.new(
          standard_options.merge(os: 'windows2019')
      )
      it_behaves_like 'a standard provisioner', packer_config_vsphere_2019

      it_behaves_like "a 2019 provisioner", packer_config_vsphere_2019

      it 'runs Set-InternetExplorerRegistries before Invoke-Sysprep is run' do
        optimize_disk_provisioner = TestProvisioner.new_powershell_provisioner("Optimize-Disk")
        internet_explorer_provisioner = TestProvisioner.new_powershell_provisioner("Set-InternetExplorerRegistries")

        expect(packer_config_vsphere_2019.provisioners).to include_provisioner(optimize_disk_provisioner, after: [internet_explorer_provisioner])
      end
    end
  end
end