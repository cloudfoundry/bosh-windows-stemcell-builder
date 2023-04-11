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

    Rake::Task['build:vsphere'].reenable
    Rake::Task['build:vsphere_add_updates'].reenable
    Rake::Task['build:vsphere_patchfile'].reenable
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@build_dir)
    FileUtils.rm_rf(@output_directory)
    FileUtils.rm_rf(@version_dir)
    FileUtils.rm_rf(@vmx_version_dir)
    FileUtils.rm_rf(@stemcell_deps_dir)
  end

  describe "with patchfile" do
    before(:each) do
      @manifest_directory = Dir.mktmpdir('manifest')
      @os_version = 'windows2019'
      @version = '1200.3.1-build.2'
      agent_commit = 'some-agent-commit'

      ENV['AWS_ACCESS_KEY_ID']= 'some-key'
      ENV['AWS_SECRET_ACCESS_KEY'] = 'secret-key'
      ENV['AWS_REGION'] = 'some-region'
      ENV['AZURE_STORAGE_ACCOUNT_NAME'] = 'some-account-name'
      ENV['AZURE_STORAGE_ACCESS_KEY'] = 'some-access-key'
      ENV['AZURE_CONTAINER_NAME'] = 'container-name'
      ENV['CACHE_DIR'] = '/tmp'
      ENV['STEMCELL_OUTPUT_BUCKET'] = 'some-stemcell-output-bucket'
      ENV['OUTPUT_BUCKET'] = 'some-output-bucket'
      ENV['VHD_VMDK_BUCKET'] = 'some-vhd-vmdk-bucket'
      ENV['PATCH_OUTPUT_BUCKET'] = 'some-patch-output-bucket'

      ENV['ADMINISTRATOR_PASSWORD'] = 'pass'
      ENV['PRODUCT_KEY'] = 'product-key'
      ENV['OWNER'] = 'owner'
      ENV['ORGANIZATION'] = 'organization'

      ENV['OS_VERSION'] = @os_version
      ENV['VERSION_DIR'] = @version_dir
      ENV['MANIFEST_DIRECTORY'] = @manifest_directory
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
        @version
      )
      File.write(
        File.join(@vmx_version_dir, 'number'),
        'some-vmx-version'
      )

      s3_vmx= double(:s3_vmx)
      allow(s3_vmx).to receive(:fetch).and_return("1234")
      allow(s3_vmx).to receive(:put)

      allow(S3::Vmx).to receive(:new).with(
        input_bucket: 'input-vmx-bucket',
        output_bucket: 'stemcell-output-bucket',
        vmx_cache_dir: '/tmp',
        endpoint: nil)
        .and_return(s3_vmx)

      allow(Executor).to receive(:exec_command)
      @vhd_version = '20181709'
      @vhd_filename = "some-last-file-Containers-#{@vhd_version}-en.us.vhd"
      s3_client= double(:s3_client)
      allow(s3_client).to receive(:list).and_return([@vhd_filename])
      allow(s3_client).to receive(:get)

      allow(S3::Client).to receive(:new).with(
        endpoint: nil
      ).and_return(s3_client)

      allow_any_instance_of(Object).to receive(:`)

      Timecop.freeze
    end

    after(:each) do
      Timecop.return
    end

    after(:each) do
      FileUtils.rm_rf(@manifest_directory)
    end

    it 'should generate a patchfile and uploads it to Azure' do
      allow(Executor).to receive(:exec_command).and_return("")
      packer_output_vmdk = File.join(@output_directory, 'fake.vmdk')
      expected_upload_command = "az storage blob upload "\
        "--container-name #{ENV['AZURE_CONTAINER_NAME']} "\
        "--account-key #{ENV['AZURE_STORAGE_ACCESS_KEY']} "\
        "--name #{@os_version}/untested/patchfile-#{@version}-#{@vhd_version} "\
        "--file #{File.join(File.expand_path(@output_directory), "patchfile-#{@version}-#{@vhd_version}")} "\
        "--account-name #{ENV['AZURE_STORAGE_ACCOUNT_NAME']}"

      expect(packer_output_vmdk).not_to be_nil
      expect(Executor).to receive(:exec_command).once.with(expected_upload_command)
      Rake::Task['build:vsphere_patchfile'].invoke
    end

    it 'should generate a manifest.yml' do
      validFrom = (Time.now.utc - 1.day).iso8601
      validTo = (Time.now.utc + 2.year).iso8601
      expected_blob_command = "az storage blob url "\
      "--container-name #{ENV['AZURE_CONTAINER_NAME']} "\
      "--name #{@os_version}/untested/patchfile-#{@version}-#{@vhd_version} "\
      "--account-name #{ENV['AZURE_STORAGE_ACCOUNT_NAME']} "\
      "--account-key #{ENV['AZURE_STORAGE_ACCESS_KEY']}"

      expected_sas_commmand = "az storage container generate-sas "\
      "--name #{ENV['AZURE_CONTAINER_NAME']} "\
      "--permissions rl "\
      "--account-name #{ENV['AZURE_STORAGE_ACCOUNT_NAME']} "\
      "--account-key #{ENV['AZURE_STORAGE_ACCESS_KEY']} "\
      "--start #{validFrom} "\
      "--expiry #{validTo}"

      expect(Executor).to receive(:exec_command).once.with(expected_blob_command).and_return(" \"some-blob-url\" ")
      expect(Executor).to receive(:exec_command).once.with(expected_sas_commmand).and_return(" \"some-sas-key\" ")

      Rake::Task['build:vsphere_patchfile'].invoke

      manifest = File.join(@manifest_directory, "patchfile-#{@version}-#{@vhd_version}.yml")
      expect(File.exist? manifest).to be(true)
      manifest_content = File.read(manifest)
      expect(manifest_content).to include("api_version: 2")
      expect(manifest_content).to include("patch_file: some-blob-url?some-sas-key")
      expect(manifest_content).to include("os_version: 2019")
      expect(manifest_content).to include("output_dir: .")
      expect(manifest_content).to include("vhd_file: #{@vhd_filename}")
      expect(manifest_content).to include("version: #{@version}")
    end
  end

  describe 'stemcell' do
    before(:each) do
      os_version = 'windows2019'
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
        input_bucket: 'input-vmx-bucket',
        output_bucket: 'stemcell-output-bucket',
        vmx_cache_dir: '/tmp',
        endpoint: nil)
        .and_return(s3_vmx)

      s3_client= double(:s3_client)
      allow(s3_client).to receive(:put)

      allow(S3::Client).to receive(:new).with(
        endpoint: nil
      ).and_return(s3_client)
    end

    it 'should build a vsphere stemcell' do
      Rake::Task['build:vsphere'].invoke

      stembuild_version_arg = JSON.parse(File.read("#{@output_directory}/myargs"))[4]
      expect(stembuild_version_arg).to eq('1200.3.1-build.2')
      stemcell_filename = File.basename(Dir["#{@output_directory}/*.tgz"].first)
      expect(stemcell_filename).to eq "bosh-stemcell-1200.3.1-build.2-vsphere-esxi-windows2019-go_agent.tgz"
    end

    context 'when we are not authorized to upload to the S3 bucket' do
      before(:each) do
        allow(S3).to receive(:test_upload_permissions).and_raise(Aws::S3::Errors::Forbidden.new('', ''))
      end

      it 'should fail before building the stemcell' do
        expect do
          Rake::Task['build:vsphere'].invoke
        end.to raise_exception(Aws::S3::Errors::Forbidden)

        files = Dir.glob(File.join(@output_directory, '*').gsub('\\', '/'))
        expect(files).to be_empty
      end
    end
  end
end
