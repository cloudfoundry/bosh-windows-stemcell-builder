require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'
require 'timecop'
require 'active_support'
require 'active_support/core_ext'

load File.expand_path('../../../../lib/tasks/build/azure.rake', __FILE__)

describe 'Azure' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    @output_directory = 'bosh-windows-stemcell'
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)
    Timecop.freeze (Time.new "2010-1-10T00:00:00Z")
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.remove_dir(@build_dir)
    FileUtils.rm_rf(@output_directory)
    Timecop.return
  end

  it 'should build an azure stemcell' do
    Dir.mktmpdir('azure-stemcell-test') do |tmpdir|
      os_version = 'some-os-version'
      version = 'some-version'
      agent_commit = 'some-agent-commit'

      ENV['CLIENT_ID'] = 'some-azure_access_key'
      ENV['CLIENT_SECRET'] = 'some-azure_secret_key'
      ENV['TENANT_ID'] = 'some-tenant-id'
      ENV['SUBSCRIPTION_ID'] = 'some-subscription-id'
      ENV["OBJECT_ID"] = 'some-object-id'
      ENV['RESOURCE_GROUP_NAME'] = 'some-resource-group-name'
      ENV['STORAGE_ACCOUNT'] = 'some-storage-account'
      ENV['LOCATION'] = 'some-location'
      ENV['VM_SIZE'] = 'some-vm-size'
      ENV['PUBLISHER'] = 'some-publisher'
      ENV['OFFER'] = 'some-offer'
      ENV['SKU'] = 'some-sku'
      ENV["ADMIN_PASSWORD"] = 'some-admin-password'
      ENV['OS_VERSION'] = os_version
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'azure')}:#{ENV['PATH']}"

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

      Rake::Task['build:azure'].invoke

      now = Time.now.utc
      yesterday = (now - 1.day).iso8601
      next_year = (now + 1.year).iso8601
      vhd_uri = File.read(File.join(@output_directory, "bosh-stemcell-#{version}-azure-vhd-uri.txt"))
      vhd_domain = (vhd_uri.split '?')[0]
      vhd_param_string = (vhd_uri.split '?')[1]
      vhd_params = CGI.parse vhd_param_string
      expect(vhd_domain).to eq "https://storageaccount.blob.core.windows.net/system/Microsoft.Compute/Images/bosh-stemcell-osDisk.blah.vhd"
      expect(vhd_params['se'].first).to eq next_year
      expect(vhd_params['st'].first).to eq yesterday
      expect(vhd_params['sr'].first).to eq 'c'
      expect(vhd_params['sp'].first).to eq 'rl'
      expect(vhd_params['sv'].first).to eq '2015-02-21'
      expect(vhd_params['sig'].first).to eq 'mysig'
      expect(vhd_uri).to eq "https://storageaccount.blob.core.windows.net/system/Microsoft.Compute/Images/bosh-stemcell-osDisk.blah.vhd?se=2011-01-01T05:00:00Z&sig=mysig&sp=rl&sr=c&sv=2015-02-21&st=2009-12-31T05:00:00Z"

      stemcell = File.join(@output_directory, "light-bosh-stemcell-#{version}-azure-#{os_version}-go_agent.tgz")
      stemcell_sha = File.join(@output_directory, "light-bosh-stemcell-#{version}-azure-#{os_version}-go_agent.tgz.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq(version)
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('azure')
      expect(stemcell_manifest['cloud_properties']['image']['offer']).to eq('some-offer')
      expect(stemcell_manifest['cloud_properties']['image']['publisher']).to eq('some-publisher')
      expect(stemcell_manifest['cloud_properties']['image']['sku']).to eq('some-sku')
      expect(stemcell_manifest['cloud_properties']['image']['version']).to eq('some-version')

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(agent_commit)

      # expect(read_from_tgz(stemcell, 'updates.txt')).to eq('some-updates')

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))
    end
  end
end
