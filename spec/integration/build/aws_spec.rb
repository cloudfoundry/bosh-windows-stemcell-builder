require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'
require 's3'

load File.expand_path('../../../../lib/tasks/build/aws.rake', __FILE__)

describe 'Aws' do
  before(:each) do
    @original_env = ENV.to_hash
    @build_dir = File.expand_path('../../../../build', __FILE__)
    @version_dir = Dir.mktmpdir('aws')
    @agent_dir = Dir.mktmpdir('aws')
    @base_amis_dir = Dir.mktmpdir('aws')
    @output_dir = 'bosh-windows-stemcell'
    @amis_dir = Dir.mktmpdir('aws-stemcell-test')
    @stemcell_deps_dir = Dir.mktmpdir('aws')
    FileUtils.rm_rf(@output_dir)
    Rake::Task['build:aws'].reenable
    Rake::Task['build:aws_ami'].reenable

    @os_version = 'windows2019'
    @version = '1200.3.1-build.2'
    @agent_commit = 'some-agent-commit'

    ENV['AMIS_DIR'] = @amis_dir
    ENV['PACKER_AWS_ACCESS_KEY'] = @aws_access_key = 'some-aws_access_key'
    ENV['PACKER_AWS_SECRET_KEY'] = @aws_secret_key = 'some-aws_secret_key'
    ENV['OS_VERSION'] = @os_version
    ENV['PATH'] = "#{File.join(File.expand_path('../../../..', __FILE__), 'spec', 'fixtures', 'aws')}:#{ENV['PATH']}"
    ENV['VERSION_DIR'] = @version_dir
    ENV['BASE_AMIS_DIR'] = @base_amis_dir
    ENV['OUTPUT_BUCKET_REGION'] = @output_bucket_region = 'some-output-bucket-region'
    ENV['OUTPUT_BUCKET_NAME'] = 'some-output-bucket-name'
    ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir

    File.write(
      File.join(@version_dir, 'number'),
      @version
    )

    FileUtils.mkdir_p(File.join(@build_dir, 'compiled-agent'))
    File.write(
      File.join(@build_dir, 'compiled-agent', 'sha'),
      @agent_commit
    )

    File.write(
      File.join(@base_amis_dir, 'base-amis-1.json'),
      {
        name: 'us-east-1',
        base_ami: 'base-east-1'
      }
    .to_json
    )
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@output_dir)
    FileUtils.rm_rf(@version_dir)
    FileUtils.rm_rf(@agent_dir)
    FileUtils.rm_rf(@base_amis_dir)
    FileUtils.rm_rf(@amis_dir)
    FileUtils.rm_rf(@stemcell_deps_dir)
  end

  describe 'Create an aws stemcell' do
    before(:each) do
      ENV['PACKER_REGION'] = @region = 'us-east-1'
    end

    it 'should build an aws stemcell' do
      allow(S3).to receive(:test_upload_permissions)

      s3_client = double(:s3_client)
      allow(s3_client).to receive(:put)
      allow(S3::Client).to receive(:new).and_return(s3_client)

      Rake::Task['build:aws'].invoke

      stemcell = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent-#{@region}.tgz")
      stemcell_sha = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent-#{@region}.tgz.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq('1200.3.1-build.2')
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(@os_version)
      expect(stemcell_manifest['api_version']).to eq(3)
      expect(stemcell_manifest['stemcell_formats']).to eq(['aws-light'])
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      expect(stemcell_manifest['cloud_properties']['encrypted']).to eq(false)
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to eq('ami-east1id')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-2']).to be_nil

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(@agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))

      # running task should create packer-output-ami.txt in AMIS_DIR
      packer_output_ami = JSON.parse(File.read(File.join(@amis_dir, "packer-output-ami-#{@version}.txt")))
      expect(packer_output_ami['region']).to eq('us-east-1')
      expect(packer_output_ami['ami_id']).to eq('ami-east1id')
    end

    context 'when we are not authorized to upload to the S3 bucket' do
      before(:each) do
        allow(S3).to receive(:test_upload_permissions).and_raise(Aws::S3::Errors::Forbidden.new('', ''))
      end

      it 'should fail before attempting to build stemcell' do
        expect do
          Rake::Task['build:aws'].invoke
        end.to raise_exception(Aws::S3::Errors::Forbidden)

        stemcell = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent-#{@region}.tgz")
        expect(File.exist?(stemcell)).to be_falsey
      end
    end
  end

  describe 'Copy an aws stemcell' do
    before(:each) do
      File.write(
        File.join(@amis_dir, "packer-output-ami-#{@version}.txt"),
        {'region' => 'us-east-1', 'ami_id' => 'ami-east1id'}.to_json
      )

      ENV['DEFAULT_STEMCELL_DIR'] = @default_stemcell_dir = Dir.mktmpdir
      fixtures_dir = File.join('spec', 'fixtures', 'aws', 'amis')
      FileUtils.cp(Dir[File.join(fixtures_dir, '*1200*-us-east-1.tgz')].first, @default_stemcell_dir)

      ENV['REGIONS'] = 'us-east-2'
      @copied_stemcells_dir = 'copied-regional-stemcells'

      allow(Executor).to receive(:exec_command)
        .with('aws ec2 describe-images --image-ids ami-east1id --region us-east-1')
        .and_return({'Images' => [{'Name' => 'some-image-name-us-east-1'}]}.to_json)

      allow(Executor).to receive(:exec_command)
        .with('aws ec2 copy-image --source-image-id ami-east1id ' \
              '--source-region us-east-1 --region us-east-2 --name some-image-name-us-east-2')
        .and_return({'ImageId' => 'ami-east2id'}.to_json)
    end

    after(:each) do
      FileUtils.rm_rf(@copied_stemcells_dir)
      FileUtils.rm_rf(@output_dir)
    end

    it 'should copy an aws stemcell' do
      ENV['REGIONS'] = 'us-east-2,us-east-3'
      allow(Executor).to receive(:exec_command)
                             .with('aws ec2 copy-image --source-image-id ami-east1id ' \
              '--source-region us-east-1 --region us-east-3 --name some-image-name-us-east-3')
                             .and_return({'ImageId' => 'ami-east3id'}.to_json)
      allow(Executor).to receive(:exec_command)
        .with('aws ec2 describe-images --image-ids ami-east2id ' \
              '--region us-east-2 --filters Name=state,Values=available,failed')
        .and_return({'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'available' }]}.to_json)

      expect(Executor).to receive(:exec_command)
        .with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
              '--launch-permission \'{"Add":[{"Group":"all"}]}\' --region us-east-2')

      allow(Executor).to receive(:exec_command)
                             .with('aws ec2 describe-images --image-ids ami-east3id ' \
              '--region us-east-3 --filters Name=state,Values=available,failed')
                             .and_return({'Images' =>[ {'ImageId'=> 'ami-east3id', 'State' => 'available' }]}.to_json)

      expect(Executor).to receive(:exec_command)
                              .with('aws ec2 modify-image-attribute --image-id ami-east3id ' \
              '--launch-permission \'{"Add":[{"Group":"all"}]}\' --region us-east-3')

      Rake::Task['build:aws_ami'].invoke

      default_stemcell = Dir[File.join(@copied_stemcells_dir, "*.tgz")].sort[0]
      manifest = YAML.load(read_from_tgz(default_stemcell, 'stemcell.MF'))
      expect(manifest['cloud_properties']['ami']['us-east-1']).to eq ('us-east-1-ami')

      copied_stemcell = Dir[File.join(@copied_stemcells_dir, "*.tgz")].sort[1]
      manifest = YAML.load(read_from_tgz(copied_stemcell, 'stemcell.MF'))
      expect(manifest['cloud_properties']['ami']['us-east-2']).to eq ('ami-east2id')
    end

    it 'should error out if aws stemcell copy fails' do
      allow(Executor).to receive(:exec_command)
        .with('aws ec2 describe-images --image-ids ami-east2id ' \
              '--region us-east-2 --filters Name=state,Values=available,failed')
        .and_return({'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'failed' }]}.to_json)

      expect(Executor).not_to receive(:exec_command)
        .with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
              '--launch-permission \'{"Add":[{"Group":"all"}]}\' --region us-east-2')

      expect do
        Rake::Task['build:aws_ami'].invoke
      end.to raise_exception
    end

    it 'should wait to make aws stemcell public if copy still pending' do
      allow(Executor).to receive(:exec_command)
        .with('aws ec2 describe-images --image-ids ami-east2id ' \
              '--region us-east-2 --filters Name=state,Values=available,failed')
        .and_return({'Images' =>[]}.to_json,
                    {'Images' =>[]}.to_json,
                    {'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'available' }]}.to_json)

      expect(Executor).to receive(:exec_command)
        .with('aws ec2 describe-images --image-ids ami-east2id ' \
              '--region us-east-2 --filters Name=state,Values=available,failed')
        .exactly(3).times

      expect(Executor).to receive(:exec_command)
        .with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
              '--launch-permission \'{"Add":[{"Group":"all"}]}\' --region us-east-2')
        .once

      Rake::Task['build:aws_ami'].invoke
    end
  end

  describe 'Create aggregate stemcell' do
    before(:each) do
      @output_dir = 'bosh-windows-stemcell'
      @copied1 = Dir.mktmpdir
      @copied2 = Dir.mktmpdir
      File.write(
          File.join(@amis_dir, "packer-output-ami-#{@version}.txt"),
          {'region' => 'us-east-1', 'ami_id' => 'ami-east1id'}.to_json
      )

      fixtures_dir = File.join('spec', 'fixtures', 'aws', 'amis')

      FileUtils.cp(Dir[File.join(fixtures_dir, '*1200*-some-region-1.tgz')].first, @copied1)
      FileUtils.cp(Dir[File.join(fixtures_dir, '*1200*-some-region-2.tgz')].first, @copied2)
      FileUtils.cp(Dir[File.join(fixtures_dir, '*1200*-some-region-3.tgz')].first, @copied2)
      FileUtils.cp(Dir[File.join(fixtures_dir, '*1200*-us-east-1.tgz')].first, @copied1)
    end

    after(:each) do
      FileUtils.rm_rf("copied-regional-stemcells")
    end

    it 'Aggregates all ami-ids into stemcell manifest' do
      ENV['COPIED_STEMCELL_DIRECTORIES']="#{@copied1},#{@copied2}"

      Rake::Task['build:aws_aggregate'].invoke

      # The implementation picks the 'first' stemcell to determine the final stemcell name.
      tar_files = Dir.entries('copied-regional-stemcells').select do |x| x.end_with?('.tgz') end
      output_tgz_name = /(.*go_agent)-(.*)\.tgz/.match(tar_files.first)[1] + ".tgz"

      stemcell = File.join(@output_dir, output_tgz_name)
      stemcell_sha = File.join(@output_dir, "#{output_tgz_name}.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq('1200.3')
      expect(stemcell_manifest['api_version']).to eq(2)
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(@os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      expect(stemcell_manifest['cloud_properties']['encrypted']).to eq(false)
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to eq('us-east-1-ami')
      expect(stemcell_manifest['cloud_properties']['ami']['some-region-1']).to eq('some-ami-1')
      expect(stemcell_manifest['cloud_properties']['ami']['some-region-2']).to eq('some-ami-2')
      expect(stemcell_manifest['cloud_properties']['ami']['some-region-3']).to eq('some-ami-3')

      expect(read_from_tgz(stemcell, 'updates.txt')).not_to be_nil

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(@agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))
    end
  end
end
