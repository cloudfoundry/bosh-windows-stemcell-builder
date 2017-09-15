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
    @version_dir = Dir.mktmpdir('vsphere')
    @vmx_version_dir = Dir.mktmpdir('vsphere')
    @stemcell_deps_dir = Dir.mktmpdir('vsphere')
    FileUtils.mkdir_p(@build_dir)
    FileUtils.rm_rf(@output_directory)
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@build_dir)
    FileUtils.rm_rf(@output_directory)
    FileUtils.rm_rf(@version_dir)
    FileUtils.rm_rf(@vmx_version_dir)
    FileUtils.rm_rf(@stemcell_deps_dir)
  end

  it 'should build a vsphere_add_updates vmx' do
    os_version = 'windows2012R2'

    ENV['AWS_ACCESS_KEY_ID']= 'some-key'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'secret-key'
    ENV['AWS_REGION'] = 'some-region'
    ENV['INPUT_BUCKET'] = 'input-vmx-bucket'
    ENV['VMX_CACHE_DIR'] = '/tmp'
    ENV['OUTPUT_BUCKET'] = 'stemcell-output-bucket'
    ENV['VERSION_DIR'] = @version_dir

    ENV['ADMINISTRATOR_PASSWORD'] = 'pass'

    ENV['OS_VERSION'] = os_version
    ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

    File.write(
      File.join(@version_dir, 'number'),
      'some-version'
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
      vmx_cache_dir: '/tmp',
      endpoint: nil)
      .and_return(s3_vmx)

    Rake::Task['build:vsphere_add_updates'].invoke
    pattern = File.join(@output_directory, "*.vmx").gsub('\\', '/')
    files = Dir.glob(pattern)
    expect(files.length).to eq(1)
    expect(files[0]).to eq(File.join(@output_directory,"file.vmx"))
  end

  describe "with diff" do
    before :each do
      FileUtils.mkdir_p("../ci/bosh-windows-stemcell-builder/create-vsphere-stemcell-from-diff")
      File.write("../ci/bosh-windows-stemcell-builder/create-vsphere-stemcell-from-diff/old-base-vmx.vmx", "some-vmx-template")
    end
    after :each do
      FileUtils.rm_rf("../ci/bosh-windows-stemcell-builder/create-vsphere-stemcell-from-diff")
    end
    it 'should build a vsphere stemcell from diff' do
      os_version = 'windows2012R2'
      version = '1200.3.1-build.2'
      agent_commit = 'some-agent-commit'

      ENV['AWS_ACCESS_KEY_ID']= 'some-key'
      ENV['AWS_SECRET_ACCESS_KEY'] = 'secret-key'
      ENV['AWS_REGION'] = 'some-region'
      ENV['CACHE_DIR'] = '/tmp'
      ENV['STEMCELL_OUTPUT_BUCKET'] = 'some-stemcell-output-bucket'
      ENV['OUTPUT_BUCKET'] = 'some-output-bucket'
      ENV['VHD_VMDK_BUCKET'] = 'some-vhd-vmdk-bucket'
      ENV['DIFF_OUTPUT_BUCKET'] = 'some-diff-output-bucket'

      ENV['ADMINISTRATOR_PASSWORD'] = 'pass'
      ENV['PRODUCT_KEY'] = 'product-key'
      ENV['OWNER'] = 'owner'
      ENV['ORGANIZATION'] = 'organization'

      ENV['OS_VERSION'] = os_version
      ENV['VERSION_DIR'] = @version_dir
      ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir
      ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

      ENV['OUTPUT_DIR'] = @output_directory

      FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
      File.write(
        File.join(@build_dir, 'compiled-agent', 'sha'),
        agent_commit
      )

      File.write(
        File.join(@version_dir, 'number'),
        version
      )
      File.write(
        File.join(@vmx_version_dir, 'number'),
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
        vmx_cache_dir: '/tmp',
        endpoint: nil)
        .and_return(s3_vmx)

      s3_client= double(:s3_client)
      allow(s3_client).to receive(:put)

      allow(S3::Client).to receive(:new).with(
        aws_access_key_id: 'some-key',
        aws_secret_access_key: 'secret-key',
        aws_region: 'some-region',
        endpoint: nil
      ).and_return(s3_client)

      allow(s3_client).to receive(:list).and_return(['some-last-file.patched-0-0.vhd'])
      allow(s3_client).to receive(:get)

      allow(Stemcell::Builder::VSphere).to receive(:find_file_by_extn).and_return('some-stemcell-path.tgz')

      Rake::Task['build:vsphere_diff'].invoke
      packer_output_vmdk = File.join(@output_directory, 'fake.vmdk')
      expect(packer_output_vmdk).not_to be_nil
      stembuild_version_arg = JSON.parse(File.read("#{@output_directory}/myargs"))[5]
      expect(stembuild_version_arg).to eq('1200.3')
      stemcell_filename = File.basename(Dir["#{@output_directory}/*.tgz"].first)
      expect(stemcell_filename).to eq "bosh-stemcell-1200.3.1-build.2-vsphere-esxi-windows2012R2-go_agent.tgz"
    end
  end

  it 'should build a vsphere stemcell' do
    os_version = 'windows2012R2'
    version = '1200.3.1-build.2'
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
    ENV['VERSION_DIR'] = @version_dir
    ENV['VMX_VERSION_DIR'] = @vmx_version_dir
    ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir
    ENV['PATH'] = "#{File.join(@build_dir, '..', 'spec', 'fixtures', 'vsphere')}:#{ENV['PATH']}"

    FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
    File.write(
      File.join(@build_dir, 'compiled-agent', 'sha'),
      agent_commit
    )

    File.write(
      File.join(@version_dir, 'number'),
      version
    )
    File.write(
      File.join(@vmx_version_dir, 'number'),
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
      vmx_cache_dir: '/tmp',
      endpoint: nil)
      .and_return(s3_vmx)

    s3_client= double(:s3_client)
    allow(s3_client).to receive(:put)

    allow(S3::Client).to receive(:new).with(
      aws_access_key_id: 'some-key',
      aws_secret_access_key: 'secret-key',
      aws_region: 'some-region',
      endpoint: nil
    ).and_return(s3_client)

    Rake::Task['build:vsphere'].invoke

    stembuild_version_arg = JSON.parse(File.read("#{@output_directory}/myargs"))[3]
    expect(stembuild_version_arg).to eq('1200.3')
    stemcell_filename = File.basename(Dir["#{@output_directory}/*.tgz"].first)
    expect(stemcell_filename).to eq "bosh-stemcell-1200.3.1-build.2-vsphere-esxi-windows2012R2-go_agent.tgz"
  end
end
