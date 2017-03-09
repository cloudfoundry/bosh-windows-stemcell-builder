require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../lib/tasks/build/gcp.rake', __FILE__)

describe 'Gcp' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../build', __FILE__)
    @output_directory = 'bosh-windows-stemcell'
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  it 'should build a gcp stemcell' do
    Dir.mktmpdir('gcp-stemcell-test') do |tmpdir|
      output_directory = File.join(tmpdir, 'gcp')
      os_version = 'some-os-version'
      version = 'some-version'
      agent_commit = 'some-agent-commit'

      ENV['ACCOUNT_JSON'] = {'project_id' => 'some-project-id'}.to_json
      ENV['OS_VERSION'] = os_version
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'gcp')}:#{ENV['PATH']}"

      FileUtils.mkdir_p(File.join(@build_dir, 'version'))
      File.write(
        File.join(@build_dir, 'version', 'number'),
        'some-version'
      )

      FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
      File.write(
        File.join(@build_dir, 'compiled-agent', 'sha'),
        agent_commit
      )

      FileUtils.mkdir_p(File.join(@build_dir, 'base-gcp-image'))
      File.write(
        File.join(@build_dir, 'base-gcp-image', 'base-gcp-image-1.json'),
        {'base_image' => 'some-base-image'}.to_json
      )

      Rake::Task['build:gcp'].invoke
      stemcell = File.join(@output_directory, "light-bosh-stemcell-#{version}-google-kvm-#{os_version}-go_agent.tgz")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq(version)
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('google')
      expect(stemcell_manifest['cloud_properties']['image_url']).to eq('https://www.googleapis.com/compute/v1/projects/some-project-id/global/images/packer-1234')

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
    end
  end
end
