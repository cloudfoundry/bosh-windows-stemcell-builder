require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/build/azure.rake', __FILE__)

describe 'Azure' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    @output_directory = 'bosh-windows-stemcell'
    @version_dir = Dir.mktmpdir('azure')
    @stemcell_deps_dir = Dir.mktmpdir('azure')
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)

    allow(Open3).to receive(:capture2e).with('az', 'login', '--service-principal', any_args).and_return(['', instance_double(Process::Status, success?: true)])
    allow(Open3).to receive(:capture2e).with('az', 'storage', 'blob', 'generate-sas', any_args) do |*args|
      expect(args).to include('some-disk-image-url')
      ['some-signed-disk-image-url', instance_double(Process::Status, success?: true)]
    end
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
    FileUtils.remove_dir(@version_dir)
    FileUtils.rm_rf(@output_directory)
    FileUtils.rm_rf(@stemcell_deps_dir)
  end

  it 'should build an azure stemcell' do
    Dir.mktmpdir('azure-stemcell-test') do |tmpdir|
      os_version = 'windows2019'
      version = '1200.0.1-build.7'
      agent_commit = 'some-agent-commit'

      ENV['CLIENT_ID'] = 'some-azure_access_key'
      ENV['CLIENT_SECRET'] = 'some-azure_secret_key'
      ENV['TENANT_ID'] = 'some-tenant-id'
      ENV['SUBSCRIPTION_ID'] = 'some-subscription-id'
      ENV['RESOURCE_GROUP_NAME'] = 'some-resource-group-name'
      ENV['STORAGE_ACCOUNT'] = 'some-storage-account'
      ENV['LOCATION'] = 'some-location'
      ENV['VM_SIZE'] = 'some-vm-size'
      ENV['PUBLISHER'] = 'some-publisher'
      ENV['OFFER'] = 'some-offer'
      ENV['SKU'] = 'some-sku'
      ENV['OS_VERSION'] = os_version
      ENV['VERSION_DIR'] = @version_dir
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'azure')}:#{ENV['PATH']}"
      ENV['BASE_IMAGE'] = 'some-base-image'
      ENV['BASE_IMAGE_OFFER'] = 'some-base-image-offer'
      ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir

      File.write(
        File.join(@version_dir, 'number'),
        version
      )

      FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
      File.write(
        File.join(@build_dir, 'compiled-agent', 'sha'),
        agent_commit
      )

      # This allows the task to be ran multiple times by different tests
      Rake::Task['build:azure'].reenable
      Rake::Task['build:azure'].invoke

      expect(File.read(File.join(@output_directory, "bosh-stemcell-#{version}-azure-vhd-uri.txt"))).to eq 'some-signed-disk-image-url'

      stemcell = File.join(@output_directory, "light-bosh-stemcell-#{version}-azure-hyperv-#{os_version}-go_agent.tgz")
      stemcell_sha = File.join(@output_directory, "light-bosh-stemcell-#{version}-azure-hyperv-#{os_version}-go_agent.tgz.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))

      expect(stemcell_manifest['version']).to eq('1200.0.1-build.7')

      expect(stemcell_manifest['api_version']).to eq(3)

      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)

      expect(stemcell_manifest['operating_system']).to eq(os_version)

      expect(stemcell_manifest['stemcell_formats']).to eq(['azure-light'])

      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('azure')
      expect(stemcell_manifest['cloud_properties']['image']['offer']).to eq('some-offer')
      expect(stemcell_manifest['cloud_properties']['image']['publisher']).to eq('some-publisher')
      expect(stemcell_manifest['cloud_properties']['image']['sku']).to eq('some-sku')
      expect(stemcell_manifest['cloud_properties']['image']['version']).to eq('1200.0.001007')

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(agent_commit)

      # expect(read_from_tgz(stemcell, 'updates.txt')).to eq('some-updates')

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))
    end
  end
end
