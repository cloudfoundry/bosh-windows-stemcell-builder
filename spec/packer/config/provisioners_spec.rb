require 'rspec/expectations'

RSpec::Matchers.define :include_provisioner do |expected_provisioner, after:[]|
  match do |actual_provisioners|
    return includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after:after)
  end
end

def provisioner_is_after?(actual_provisioners, after, provisioner_index)
  after_index = actual_provisioners.find_index do |provisioner|
    after[0].matches? provisioner
  end
  return provisioner_index != nil && after_index != nil && provisioner_index > after_index
end

def includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after:[])
  provisioner_index = actual_provisioners.find_index do |provisioner|
    expected_provisioner.matches? provisioner
  end
  if after == nil || after.length == 0
    return provisioner_index != nil
  elsif after.length == 1
    return provisioner_is_after?(actual_provisioners, after, provisioner_index)
  else
    if includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after:[after[0]])
      return includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after:after[1, -1])
    else
      return false
    end
  end
end

class TestProvisioner
  attr_accessor :command, :source, :destination, :provisioner_type

  def self.new_file_provisioner(source, destination)
    provisioner = new
    provisioner.provisioner_type = :file
    provisioner.source = source
    provisioner.destination = destination
    provisioner
  end

  def self.new_powershell_provisioner(command)
    provisioner = new
    provisioner.provisioner_type = :powershell
    provisioner.command = command
    provisioner
  end

  def matches?(actual_provisioner)
    case @provisioner_type
      when :powershell
        actual_provisioner['type'] == 'powershell' &&
        actual_provisioner.has_key?('inline') &&
        actual_provisioner['inline'].include?(@command)
      when :file
        actual_provisioner['type'] == 'file' &&
        actual_provisioner['source'] == @source &&
        actual_provisioner['destination'] == @destination
      else
        false
    end
  end
end

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

  it 'does not have nonsense provisioner' do
    nonsense_provisioner = TestProvisioner.new_powershell_provisioner('some-garbage')
    expect(@provisioners).not_to include_provisioner(nonsense_provisioner), 'test matcher'
  end

  it 'uploads bosh ps-modules' do
    upload_bosh_ps_modules = TestProvisioner.new_file_provisioner('build/bosh-psmodules.zip', 'C:\provision\bosh-psmodules.zip')
    expect(@provisioners).to include_provisioner(upload_bosh_ps_modules)
  end

  it 'uploads the install-bosh-psmodules script' do
    upload_install_bosh_ps_modules = TestProvisioner.new_file_provisioner(
        'scripts/install-bosh-psmodules.ps1',
        'C:\provision\install-bosh-psmodules.ps1'
    )
    expect(@provisioners).to include_provisioner(upload_install_bosh_ps_modules)
  end

  it 'runs install bosh ps modules after uploading zip file and install script' do
    #TODO use test provisioner matcher, while driving out order
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')
    upload_modules = TestProvisioner.new_file_provisioner('build/bosh-psmodules.zip', 'C:\provision\bosh-psmodules.zip')
    upload_install_modules = TestProvisioner.new_file_provisioner(
        'scripts/install-bosh-psmodules.ps1',
        'C:\provision\install-bosh-psmodules.ps1'
    )

    expect(@provisioners).to include_provisioner(install_modules_provisioner, after:[upload_install_modules, upload_modules])
    # prov_index = @provisioners.find_index do |x|
    #   x['type'] == 'powershell' && x.has_key?('inline') && x['inline'].include?('C:\provision\install-bosh-psmodules.ps1')
    # end
    #
    # expect(prov_index).not_to be_nil
    #
    # zip_index = @provisioners.find_index do |x|
    #   x['type'] == 'file' && x['source'] == 'build/bosh-psmodules.zip' && x['destination'] == 'C:\provision\bosh-psmodules.zip'
    # end
    #
    # install_script_index = @provisioners.find_index do |x|
    #   x['type'] == 'file' && x['source'] == 'scripts/install-bosh-psmodules.ps1' && x['destination'] == 'C:\provision\install-bosh-psmodules.ps1'
    # end
    #
    # expect(prov_index).to be > zip_index
    # expect(prov_index).to be > install_script_index
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
    register_windows_updates_task_provisioner = TestProvisioner.new_powershell_provisioner('Register-WindowsUpdatesTask')
    expect(@provisioners).to include_provisioner(register_windows_updates_task_provisioner), 'test matcher'


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