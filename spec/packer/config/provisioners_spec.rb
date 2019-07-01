describe 'provisioners' do
  before(:context) do
    stemcell_deps_dir = Dir.mktmpdir('gcp')
    ENV['STEMCELL_DEPS_DIR'] = stemcell_deps_dir

    @provisioners = Packer::Config::Aws.new(
        aws_access_key: '',
        aws_secret_key: '',
        region: '',
        output_directory: 'some-output-directory',
        os: 'windows2012R2',
        version: '1200.1.2',
        vm_prefix: '',
        mount_ephemeral_disk: false
    ).provisioners

    FileUtils.rm_rf(stemcell_deps_dir)
    ENV.delete('STEMCELL_DEPS_DIR')
  end

  it 'uploads bosh ps-modules' do
    expect(@provisioners.detect do |x|
      x['type'] == 'file' && x['source'] == 'build/bosh-psmodules.zip' && x['destination'] == 'C:\provision\bosh-psmodules.zip'
    end).not_to be_nil
  end

  it 'uploads the install-bosh-psmodules script' do
    expect(@provisioners.detect do |x|
      x['type'] == 'file' && x['source'] == 'scripts/install-bosh-psmodules.ps1' && x['destination'] == 'C:\provision\install-bosh-psmodules.ps1'
    end).not_to be_nil
  end

  it 'runs install bosh ps modules after uploading zip file and install script' do
    prov_index = @provisioners.find_index do |x|
      x['type'] == 'powershell' && x.has_key?('inline') && x['inline'].include?('C:\provision\install-bosh-psmodules.ps1')
    end

    expect(prov_index).not_to be_nil

    zip_index = @provisioners.find_index do |x|
      x['type'] == 'file' && x['source'] == 'build/bosh-psmodules.zip' && x['destination'] == 'C:\provision\bosh-psmodules.zip'
    end

    install_script_index = @provisioners.find_index do |x|
      x['type'] == 'file' && x['source'] == 'scripts/install-bosh-psmodules.ps1' && x['destination'] == 'C:\provision\install-bosh-psmodules.ps1'
    end

    expect(prov_index).to be > zip_index
    expect(prov_index).to be > install_script_index
  end

  it 'runs get-hotfix after hotfixes applied' do
    # noinspection RubyInterpreter
    prov_index = @provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Get-HotFix > hotfixes.log')
    end
    expect(prov_index).not_to be_nil, 'Could not find Get-Hotfix provisioner'


    hotfixes_applied_index = @provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Register-WindowsUpdatesTask')
    end

    unregister_windows_index = @provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Unregister-WindowsUpdatesTask')
    end

    expect(prov_index).to be > hotfixes_applied_index, 'Print Hotfix provisioner not after Windows-Updates'
    expect(prov_index).to be > unregister_windows_index, 'Print Hotfix provisioner not after Unregister Windows-Updates'
  end

  it 'Runs Unregister windows update after the post-RegisterWindowsUpdates windows-restart' do
    # noinspection RubyInterpreter
    register_updates_index = @provisioners.find_index do |p|
      p['type'] == 'powershell' && p.has_key?('inline') && p['inline'].include?('Register-WindowsUpdatesTask')
    end
    expect(register_updates_index).not_to be_nil, 'Could not find RegisterWindowsUpdates provisioner'

    post_register_provisioners = @provisioners[(register_updates_index + 1)..-1]

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