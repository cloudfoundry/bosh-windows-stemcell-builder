require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../lib/tasks/build/aws.rake', __FILE__)

describe 'Aws' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../build', __FILE__)
    FileUtils.mkdir_p(@build_dir)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
  end

  it 'should build a aws stemcell' do
    Dir.mktmpdir('aws-stemcell-test') do |tmpdir|
      output_dir = File.join(tmpdir, 'aws')
      os_version = 'some-os-version'
      version = 'some-version'
      agent_commit = 'some-agent-commit'

      ENV['AWS_ACCESS_KEY'] = 'some-aws_access_key'
      ENV['AWS_SECRET_KEY'] = 'some-aws_secret_key'
      ENV['OS_VERSION'] = os_version
      ENV['OUTPUT_DIR'] = output_dir
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'aws')}:#{ENV['PATH']}"

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

      FileUtils.mkdir_p(File.join(@build_dir, 'base-amis'))
      File.write(
        File.join(@build_dir, 'base-amis', 'base-amis-1.json'),
        [
            {
              "name" => "us-east-1",
              "base_ami" => "base-east-1"
            },
            {
              "name" => "us-east-2",
              "base_ami" => "base-east-2"
            }
        ].to_json
      )

      Rake::Task['build:aws'].invoke

      stemcell = File.join(output_dir, "light-bosh-stemcell-#{version}-aws-#{os_version}-go_agent.tgz")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq(version)
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to eq('ami-east1id')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-2']).to eq('ami-east2id')

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
    end
  end
end
