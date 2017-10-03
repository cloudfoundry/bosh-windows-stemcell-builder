require 's3'
require 'fileutils'

describe S3 do
  describe 'instance methods' do
    before :each do
      s3_resource = double(:s3_resource)
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
      s3_bucket = double(:s3_bucket)
      allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
      s3_object = double(:s3_object)
      allow(s3_bucket).to receive(:object).and_return(s3_object) # for #put
      allow(s3_bucket).to receive(:objects).and_return([]) # for #list
      allow(s3_object).to receive(:upload_file).and_return(nil)

      s3 = double(:s3)
      allow(Aws::S3::Client).to receive(:new).and_return(s3)
      allow(File).to receive(:open) # WARN

      @s3_client = S3::Client.new(
        aws_access_key_id: 'some-key-id',
        aws_secret_access_key: 'some-secret-access-key',
        aws_region: 'some-region',
        endpoint: ''
      )
    end
    describe '#list' do
      context 'when bucket contains slashes' do
        let(:bucket) { 'bucket/with/slashes' }
        it 'lists rationalized bucket' do
          expect{ @s3_client.list(bucket) }.to output(
            /Listing bucket bucket with prefix with\/slashes/
          ).to_stdout
        end
      end
      context 'when bucket does not contain slashes' do
        let(:bucket) { 'bucket-without-slashes' }
        it 'lists' do
          expect{ @s3_client.list(bucket) }.to output(
            /Listing bucket bucket-without-slashes with prefix /
          ).to_stdout
        end
      end
    end
    describe '#get' do
      context 'when bucket contains slashes' do
        let(:bucket) { 'bucket/with/slashes' }
        let(:key) { 'some-file-in-s3' }
        let(:file_name) { 'some-local-filename' }
        it 'gets from rationalized bucket and key' do
          expect{ @s3_client.get(bucket, key, file_name) }.to output(
            /Downloading the with\/slashes\/some-file-in-s3 from bucket to some-local-filename*/
          ).to_stdout
        end
      end
      context 'when bucket does not contain slashes' do
        let(:bucket) { 'bucket-without-slashes' }
        let(:key) { 'some-file-in-s3' }
        let(:file_name) { 'some-local-filename' }
        it 'gets from bucket and key' do
          expect{ @s3_client.get(bucket, key, file_name) }.to output(
            /Downloading the some-file-in-s3 from bucket-without-slashes to some-local-filename*/
          ).to_stdout
        end
      end
    end
    describe '#put' do
      context 'when bucket contains slashes' do
        let(:bucket) { 'bucket/with/slashes' }
        let(:key) { 'some-file-in-s3' }
        let(:file_name) { 'some-local-filename' }
        it 'puts to rationalized bucket and key' do
          expect{ @s3_client.put(bucket, key, file_name) }.to output(
            /Uploading the some-local-filename to bucket:with\/slashes\/some-file-in-s3*/
          ).to_stdout
        end
      end
      context 'when bucket does not contain slashes' do
        let(:bucket) { 'bucket-without-slashes' }
        let(:key) { 'some-file-in-s3' }
        let(:file_name) { 'some-local-filename' }
        it 'puts to bucket and key' do
          expect{ @s3_client.put(bucket, key, file_name) }.to output(
            /Uploading the some-local-filename to bucket-without-slashes:some-file-in-s3*/
          ).to_stdout
        end
      end
    end
  end
  describe 'Vmx' do
    it 'picks the correct version' do
      aws_access_key_id = 'some-key'
      aws_secret_access_key = 'some-secret'
      aws_region = 'some-region'
      input_bucket = 'some-input-bucket'
      output_bucket = 'some-output-bucket'
      vmx_cache_dir = Dir.mktmpdir('')
      version = '2.0.0'

      s3_client= double(:s3_client)
      allow(S3::Client).to receive(:new)
        .with(
          aws_access_key_id: aws_access_key_id,
          aws_secret_access_key: aws_secret_access_key,
          aws_region: aws_region,
          endpoint: '').and_return(s3_client)

      vmx_version = "vmx-v2.tgz"
      allow(s3_client).to receive(:get)
        .with(input_bucket, vmx_version, File.join(vmx_cache_dir, vmx_version)) do
          tarball_path = File.expand_path('../fixtures/vsphere/dummy-vmx-tarball.tgz', __FILE__)
          FileUtils.cp(tarball_path, File.join(vmx_cache_dir, vmx_version))
      end

      file = S3::Vmx.new(
        aws_access_key_id: aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key,
        aws_region: aws_region,
        input_bucket: input_bucket,
        output_bucket: output_bucket,
        vmx_cache_dir: vmx_cache_dir
      ).fetch(version)

      expect(file).to eq(File.join(vmx_cache_dir, '2', 'image.vmx'))
    end
  end
end
