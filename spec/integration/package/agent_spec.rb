require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/package/agent.rake', __FILE__)

describe 'Package::Agent' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    FileUtils.mkdir_p(@build_dir)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@build_dir)
  end
  it 'should bundle bosh agent + deps into zip files' do
    Rake::Task['package:agent'].invoke
    pattern = File.join(@build_dir, "agent.zip").gsub('\\', '/')
    files = Dir.glob(pattern)
    expect(files.length).to eq(1)
    zip_file = files[0]
    files_in_zip = zip_file_list(zip_file)
    expect(files_in_zip).to include(
      'deps/',
      'deps/bosh-blobstore-dav.exe',
      'deps/bosh-blobstore-s3.exe',
      'deps/job-service-wrapper.exe',
      'deps/pipe.exe',
      'deps/tar.exe',
      'deps/zlib1.dll',
      'bosh-agent.exe',
      'service_wrapper.exe',
      'service_wrapper.xml')
  end

end
