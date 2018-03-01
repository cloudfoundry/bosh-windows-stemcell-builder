require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/build/gcp.rake', __FILE__)

describe 'Gcp' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    @output_directory = 'bosh-windows-stemcell'
    @version_dir = Dir.mktmpdir('gcp')
    @base_image_dir = Dir.mktmpdir('gcp')
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
    FileUtils.remove_dir(@version_dir)
    FileUtils.remove_dir(@base_image_dir)
    FileUtils.rm_rf(@output_directory)
  end

  it 'should build a gcp stemcell' do
    Dir.mktmpdir('gcp-stemcell-test') do |tmpdir|
      os_version = 'windows2012R2'
      version = '1200.3.1-build.2'
      agent_commit = 'some-agent-commit'

      ENV['ACCOUNT_JSON'] = {'project_id' => 'some-project-id'}.to_json
      ENV['OS_VERSION'] = os_version
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'gcp')}:#{ENV['PATH']}"
      ENV['VERSION_DIR'] = @version_dir
      ENV['BASE_IMAGE_DIR'] = @base_image_dir

      File.write(
        File.join(@version_dir, 'number'),
        version
      )

      FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
      File.write(
        File.join(@build_dir, 'compiled-agent', 'sha'),
        agent_commit
      )

      File.write(
        File.join(@base_image_dir, 'base-gcp-image-1.json'),
        {'base_image' => 'some-base-image', 'image_family' => 'some-family'}.to_json
      )

      Rake::Task['build:gcp'].invoke
      stemcell = File.join(@output_directory, "light-bosh-stemcell-#{version}-google-kvm-#{os_version}-go_agent.tgz")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq('1200.3')
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(os_version)
      expect(stemcell_manifest['stemcell_formats']).to eq(['google-light'])
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('google')
      expect(stemcell_manifest['cloud_properties']['image_url']).to eq('https://www.googleapis.com/compute/v1/projects/some-project-id/global/images/packer-1234')

      update_list = read_from_tgz(stemcell, 'updates.txt')
      expect(update_list).to eq('some-updates')

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
    end
  end
end
