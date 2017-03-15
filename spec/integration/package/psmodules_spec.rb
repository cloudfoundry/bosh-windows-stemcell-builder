require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/package/psmodules.rake', __FILE__)

describe 'Package::PSModules' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    FileUtils.mkdir_p(@build_dir)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@build_dir)
  end
  it 'should bundle bosh PSModules into zip files' do
    Rake::Task['package:psmodules'].invoke
    pattern = File.join(@build_dir, "bosh-psmodules.zip").gsub('\\', '/')
    files = Dir.glob(pattern)
    expect(files.length).to eq(1)
    zip_file = files[0]
    files_in_zip = zip_file_list(zip_file)
    expect(files_in_zip).to include(
      'BOSH.Agent/',
      'BOSH.Agent/BOSH.Agent.psm1',
      'BOSH.Agent/BOSH.Agent.psd1',
      'BOSH.Autologon/',
      'BOSH.Autologon/BOSH.Autologon.psm1',
      'BOSH.Autologon/BOSH.Autologon.psd1',
      'BOSH.CFCell/',
      'BOSH.CFCell/BOSH.CFCell.psm1',
      'BOSH.CFCell/BOSH.CFCell.psd1',
      'BOSH.Utils/',
      'BOSH.Utils/BOSH.Utils.psm1',
      'BOSH.Utils/BOSH.Utils.psd1',
      'BOSH.WindowsUpdates/',
      'BOSH.WindowsUpdates/BOSH.WindowsUpdates.psm1',
      'BOSH.WindowsUpdates/BOSH.WindowsUpdates.psd1',
      'BOSH.WinRM/',
      'BOSH.WinRM/BOSH.WinRM.psm1',
      'BOSH.WinRM/BOSH.WinRM.psd1')
  end

end
