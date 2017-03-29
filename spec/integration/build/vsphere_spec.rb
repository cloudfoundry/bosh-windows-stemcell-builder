require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/build/vsphere.rake', __FILE__)

describe 'VSphere' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    @output_directory = 'bosh-windows-stemcell'
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  it 'should build a vsphere_add_updates vmx' do
    os_version = 'some-os-version'

    ENV['AWS_ACCESS_KEY_ID']= 'some-key'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'secret-key'
    ENV['AWS_REGION'] = 'some-region'
    ENV['INPUT_BUCKET'] = 'input-vmx-bucket'
    ENV['VMX_CACHE_DIR'] = '/tmp'
    ENV['OUTPUT_BUCKET'] = 'stemcell-output-bucket'

    ENV['ADMINISTRATOR_PASSWORD'] = 'pass'

    ENV['OS_VERSION'] = os_version
    ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

    FileUtils.mkdir_p(File.join(@build_dir, 'vmx-version'))
    File.write(
      File.join(@build_dir, 'vmx-version', 'number'),
      'some-vmx-version'
    )


    s3_vmx= double(:s3_vmx)
    allow(s3_vmx).to receive(:fetch).and_return("1234")
    allow(s3_vmx).to receive(:put)

    allow(S3::Vmx).to receive(:new).with(
      aws_access_key_id: 'some-key',
      aws_secret_access_key: 'secret-key',
      aws_region: 'some-region',
      input_bucket: 'input-vmx-bucket',
      output_bucket: 'stemcell-output-bucket',
      vmx_cache_dir: '/tmp')
      .and_return(s3_vmx)

    Rake::Task['build:vsphere_add_updates'].invoke
    pattern = File.join(@output_directory, "*.vmx").gsub('\\', '/')
    files = Dir.glob(pattern)
    expect(files.length).to eq(1)
    expect(files[0]).to eq(File.join(@output_directory,"file.vmx"))
  end

  it 'should build a vsphere stemcell' do
    os_version = 'some-os-version'
    version = 'some-version'
    agent_commit = 'some-agent-commit'

    ENV['AWS_ACCESS_KEY_ID']= 'some-key'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'secret-key'
    ENV['AWS_REGION'] = 'some-region'
    ENV['INPUT_BUCKET'] = 'input-vmx-bucket'
    ENV['VMX_CACHE_DIR'] = '/tmp'
    ENV['OUTPUT_BUCKET'] = 'stemcell-output-bucket'

    ENV['ADMINISTRATOR_PASSWORD'] = 'pass'
    ENV['PRODUCT_KEY'] = 'product-key'
    ENV['OWNER'] = 'owner'
    ENV['ORGANIZATION'] = 'organization'

    ENV['OS_VERSION'] = os_version
    ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

    FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
    File.write(
      File.join(@build_dir, 'compiled-agent', 'sha'),
      agent_commit
    )

    FileUtils.mkdir_p(File.join(@build_dir, 'version'))
    File.write(
      File.join(@build_dir, 'version', 'number'),
      version
    )
    FileUtils.mkdir_p(File.join(@build_dir, 'vmx-version'))
    File.write(
      File.join(@build_dir, 'vmx-version', 'number'),
      'some-vmx-version'
    )


    s3_vmx= double(:s3_vmx)
    allow(s3_vmx).to receive(:fetch).and_return("1234")
    allow(s3_vmx).to receive(:put)

    allow(S3::Vmx).to receive(:new).with(
      aws_access_key_id: 'some-key',
      aws_secret_access_key: 'secret-key',
      aws_region: 'some-region',
      input_bucket: 'input-vmx-bucket',
      output_bucket: 'stemcell-output-bucket',
      vmx_cache_dir: '/tmp')
      .and_return(s3_vmx)

    s3_client= double(:s3_client)
    allow(s3_client).to receive(:put)

    allow(S3::Client).to receive(:new).with(
      aws_access_key_id: 'some-key',
      aws_secret_access_key: 'secret-key',
      aws_region: 'some-region'
    ).and_return(s3_client)


    Rake::Task['build:vsphere'].invoke
    stemcell = File.join(@output_directory, "bosh-stemcell-#{version}-vsphere-esxi-#{os_version}-go_agent.tgz")

    stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
    expect(stemcell_manifest['version']).to eq(version)
    expect(stemcell_manifest['sha1']).to_not be_empty
    expect(stemcell_manifest['operating_system']).to eq(os_version)
    expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('vsphere')

    apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
    expect(apply_spec['agent_commit']).to eq(agent_commit)

    updates_list = read_from_tgz(stemcell, 'updates.txt')
    expect(updates_list).to eq('some-updates')

    Dir.mktmpdir do |tmpdir|
      tgz_extract(stemcell, tmpdir)
      image_filename = File.join(tmpdir, "image")
      ovf_file_content = read_from_tgz(image_filename, "image.ovf")
      expect(ovf_file_content).to_not include('ethernet')
    end

    expect(read_from_tgz(stemcell, 'image')).to_not be_nil
  end
end
