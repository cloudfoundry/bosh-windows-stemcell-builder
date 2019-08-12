require 'rspec/expectations'

RSpec::Matchers.define :include_provisioner do |expected_provisioner, after:[]|

  def provisioner_is_after?(actual_provisioners, after, provisioner_index)
    after_index = actual_provisioners.find_index do |provisioner|
      after.matches? provisioner
    end
    if after_index == nil
      @failure_message = "after: \n\t#{after.inspect}, which does not exist"
    elsif provisioner_index <= after_index
      @failure_message = "after:\n\t#{after.inspect}"
    end
    return provisioner_index != nil && after_index != nil && provisioner_index > after_index
  end

  def includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after)
    provisioner_index = actual_provisioners.find_index do |provisioner|
      expected_provisioner.matches? provisioner
    end

    provisioner_found = false
    if after.length == 0
      provisioner_found = provisioner_index != nil
    elsif provisioner_is_after?(actual_provisioners, after[0], provisioner_index)
      provisioner_found = includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after[1..-1])
    end

    return provisioner_found
  end

  match do |actual_provisioners|
    return includes_provisioner_ordered?(actual_provisioners, expected_provisioner, after)
  end
  description do
    "include \n\t#{expected_provisioner.inspect} #{@failure_message}"
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

  def inspect
    case @provisioner_type
      when :powershell
        return "Powershell provisioner with command: '#{@command}'"
      when :file
        return "File Provisioner with source: '#{@source}' and destination: '#{@destination}'"
    end
  end

  def matches?(actual_provisioner)
    case @provisioner_type
      when :powershell
        actual_provisioner['type'] == 'powershell' &&
        actual_provisioner.has_key?('inline') &&
        actual_provisioner['inline'].find do |script_line|
          if @command.is_a?(String)
            script_line.eql? @command
          elsif @command.is_a?(Regexp)
            script_line =~ @command
          else
            raise "provisioner command neither string nor regex"
          end
        end
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
    install_modules_provisioner = TestProvisioner.new_powershell_provisioner('C:\provision\install-bosh-psmodules.ps1')
    upload_modules = TestProvisioner.new_file_provisioner('build/bosh-psmodules.zip', 'C:\provision\bosh-psmodules.zip')
    upload_install_modules = TestProvisioner.new_file_provisioner(
        'scripts/install-bosh-psmodules.ps1',
        'C:\provision\install-bosh-psmodules.ps1'
    )

    expect(@provisioners).to include_provisioner(install_modules_provisioner, after:[upload_install_modules, upload_modules])
  end

  it 'runs get-hotfix after windows updates are applied' do
    get_hotfix_prov = TestProvisioner.new_powershell_provisioner('Get-HotFix > hotfixes.log')
    wait_windows_update_prov = TestProvisioner.new_powershell_provisioner(/Wait-WindowsUpdates -Password .+ -User Provisioner/)
    expect(@provisioners).to include_provisioner(get_hotfix_prov, after:[wait_windows_update_prov])
    # expect(@provisioners).to include_provisioner(get_hotfix_prov)

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

  it 'runs Unregister windows update after the post-RegisterWindowsUpdates windows-restart' do
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