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
    FileUtils.rm_rf(@output_dir)
    Rake::Task['build:aws'].reenable

    @os_version = 'windows2012R2'
    @version = '1200.3.1-build.2'
    @agent_commit = 'some-agent-commit'

    ENV['AMIS_DIR'] = @amis_dir
    ENV['AWS_ACCESS_KEY'] = @aws_access_key = 'some-aws_access_key'
    ENV['AWS_SECRET_KEY'] = @aws_secret_key = 'some-aws_secret_key'
    ENV['OS_VERSION'] = @os_version
    ENV['PATH'] = "#{File.join(File.expand_path('../../../..', __FILE__), 'spec', 'fixtures', 'aws')}:#{ENV['PATH']}"
    ENV['VERSION_DIR'] = @version_dir
    ENV['BASE_AMIS_DIR'] = @base_amis_dir
    ENV['OUTPUT_BUCKET_REGION'] = @output_bucket_region = 'some-output-bucket-region'
    ENV['OUTPUT_BUCKET_NAME'] = 'some-output-bucket-name'

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
  end

  after(:each) do
    ENV.replace(@original_env)
    FileUtils.rm_rf(@output_dir)
    FileUtils.rm_rf(@version_dir)
    FileUtils.rm_rf(@agent_dir)
    FileUtils.rm_rf(@base_amis_dir)
    FileUtils.rm_rf(@amis_dir)
  end

  describe 'Create an aws stemcell' do
    before(:each) do
      ENV['REGION'] = @region = 'us-east-1'
    end

    it 'should build an aws stemcell' do
      s3_client = double(:s3_client)
      allow(s3_client).to receive(:put)
      allow(S3::Client).to receive(:new).with(
        aws_access_key_id: @aws_access_key,
        aws_secret_access_key: @aws_secret_key,
        aws_region: @output_bucket_region
      ).and_return(s3_client)

      Rake::Task['build:aws'].invoke

      stemcell = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent-#{@region}.tgz")
      stemcell_sha = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent-#{@region}.tgz.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq('1200.3')
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(@os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to eq('ami-east1id')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-2']).to be_nil

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(@agent_commit)

      expect(read_from_tgz(stemcell, 'updates.txt')).to eq('some-updates')

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))

      # running task should create packer-output-ami.txt in AMIS_DIR
      packer_output_ami = JSON.parse(File.read(File.join(@amis_dir, "packer-output-ami-#{@version}.txt")))
      expect(packer_output_ami['region']).to eq('us-east-1')
      expect(packer_output_ami['ami_id']).to eq('ami-east1id')
    end
  end

  describe 'Copy an aws stemcell' do
    before(:each) do
      File.write(
        File.join(@amis_dir, "packer-output-ami-#{@version}.txt"),
        {'region' => 'us-east-1', 'ami_id' => 'ami-east1id'}.to_json
      )
      ENV['REGIONS'] = @region = 'us-east-2'
      @copied_stemcells_dir = 'copied-regional-stemcells'
      @output_dir = 'bosh-windows-stemcell'

      # Simulate concourse input
      ENV['DEFAULT_STEMCELL_DIR'] = @default_stemcell_dir = Dir.mktmpdir
      fixtures_dir = File.join('spec', 'fixtures', 'aws', 'amis')
      FileUtils.cp(Dir[File.join(fixtures_dir, "*-us-east-1.tgz")].first, @default_stemcell_dir)

      s3_client = double(:s3_client)
      allow(s3_client).to receive(:put)
      allow(S3::Client).to receive(:new).with(
          aws_access_key_id: @aws_access_key,
          aws_secret_access_key: @aws_secret_key,
          aws_region: @output_bucket_region
      ).and_return(s3_client)

      allow(Executor).to receive(:exec_command).
          with('aws ec2 describe-images --image-ids ami-east1id --region us-east-1').
          and_return({'Images' => [{'Name' => 'some-image-name-us-east-1'}]}.to_json)

      allow(Executor).to receive(:exec_command).
          with('aws ec2 copy-image --source-image-id ami-east1id ' \
             '--source-region us-east-1 --region us-east-2 --name some-image-name-us-east-2').
          and_return({'ImageId' => 'ami-east2id'}.to_json)

      allow(Executor).to receive(:exec_command).
          with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
          '--launch-permission "{"Add":[{"Group":"all"}]}" --region us-east-2').
          and_return(nil)

    end

    after(:each) do
      FileUtils.rm_rf(@default_stemcell_dir)
      FileUtils.rm_rf(@copied_stemcells_dir)
      FileUtils.rm_rf(@output_dir)
    end

    it 'should copy an aws stemcell' do

      allow(Executor).to receive(:exec_command).with('aws ec2 describe-images --image-ids ami-east2id ' \
          '--region us-east-2 --filters Name=state,Values=available,failed').
          and_return({'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'available' }]}.to_json)

      expect(Executor).to receive(:exec_command).
          with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
          '--launch-permission "{"Add":[{"Group":"all"}]}" --region us-east-2')

      Rake::Task['build:aws_ami'].reenable
      Rake::Task['build:aws_ami'].invoke

      stemcell = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent.tgz")
      stemcell_sha = File.join(@output_dir, "light-bosh-stemcell-#{@version}-aws-xen-hvm-#{@os_version}-go_agent.tgz.sha")

      stemcell_manifest = YAML.load(read_from_tgz(stemcell, 'stemcell.MF'))
      expect(stemcell_manifest['version']).to eq('1200.3')
      expect(stemcell_manifest['sha1']).to eq(EMPTY_FILE_SHA)
      expect(stemcell_manifest['operating_system']).to eq(@os_version)
      expect(stemcell_manifest['cloud_properties']['infrastructure']).to eq('aws')
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-1']).to be_nil
      expect(stemcell_manifest['cloud_properties']['ami']['us-east-2']).to eq('ami-east2id')

      expect(read_from_tgz(stemcell, 'updates.txt')).not_to be_nil

      apply_spec = JSON.parse(read_from_tgz(stemcell, 'apply_spec.yml'))
      expect(apply_spec['agent_commit']).to eq(@agent_commit)

      expect(read_from_tgz(stemcell, 'image')).to be_nil
      expect(File.read(stemcell_sha)).to eq(Digest::SHA1.hexdigest(File.read(stemcell)))
    end

    it 'should error out if aws stemcell copy fails' do
      allow(Executor).to receive(:exec_command).with('aws ec2 describe-images --image-ids ami-east2id ' \
        '--region us-east-2 --filters Name=state,Values=available,failed').
        and_return({'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'failed' }]}.to_json)

      expect(Executor).not_to receive(:exec_command).
        with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
        '--launch-permission "{"Add":[{"Group":"all"}]}" --region us-east-2')

      expect do
        Rake::Task['build:aws_ami'].reenable
        Rake::Task['build:aws_ami'].invoke
      end.to raise_exception
    end

    it 'should wait to make aws stemcell public if copy still pending' do
      allow(Executor).to receive(:exec_command).with('aws ec2 describe-images --image-ids ami-east2id ' \
          '--region us-east-2 --filters Name=state,Values=available,failed').
          and_return({'Images' =>[]}.to_json,
            {'Images' =>[]}.to_json,
            {'Images' =>[ {'ImageId'=> 'ami-east2id', 'State' => 'available' }]}.to_json)

      expect(Executor).to receive(:exec_command).with('aws ec2 describe-images --image-ids ami-east2id ' \
          '--region us-east-2 --filters Name=state,Values=available,failed').exactly(3).times

      expect(Executor).to receive(:exec_command).
          with('aws ec2 modify-image-attribute --image-id ami-east2id ' \
          '--launch-permission "{"Add":[{"Group":"all"}]}" --region us-east-2').once

      Rake::Task['build:aws_ami'].reenable
      Rake::Task['build:aws_ami'].invoke
    end

  end
end
