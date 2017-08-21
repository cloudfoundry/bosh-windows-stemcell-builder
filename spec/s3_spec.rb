require 's3'
require 'fileutils'

describe S3 do
  describe 'Vmx' do
    it 'pick the correct version' do
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
