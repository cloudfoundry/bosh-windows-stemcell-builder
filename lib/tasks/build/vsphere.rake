require 'rspec/core/rake_task'
require 'json'
require_relative '../../s3'

namespace :build do
  desc 'Apply Windows Updates for VMX'
  task :vsphere_add_updates do
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    vmx_version = File.read(File.join(version_dir, 'number')).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf(output_directory)

    vmx = S3::Vmx.new(
      aws_access_key_id: Stemcell::Builder::validate_env("AWS_ACCESS_KEY_ID"),
      aws_secret_access_key: Stemcell::Builder::validate_env("AWS_SECRET_ACCESS_KEY"),
      aws_region: Stemcell::Builder::validate_env("AWS_REGION"),
      input_bucket: Stemcell::Builder::validate_env("INPUT_BUCKET"),
      output_bucket: Stemcell::Builder::validate_env("OUTPUT_BUCKET"),
      vmx_cache_dir: Stemcell::Builder::validate_env("VMX_CACHE_DIR")
    )

    source_path = vmx.fetch(vmx_version)

    vsphere = Stemcell::Builder::VSphereAddUpdates.new(
      administrator_password: Stemcell::Builder::validate_env("ADMINISTRATOR_PASSWORD"),
      source_path: source_path,
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '8'),
      output_directory: output_directory,
      packer_vars: {},
    )

    vsphere.build
    vmx.put(output_directory, vmx_version)
  end

  desc 'Build VSphere Stemcell'
  task :vsphere do
    build_dir = File.expand_path("../../../../build", __FILE__)

    aws_access_key_id = Stemcell::Builder::validate_env('AWS_ACCESS_KEY_ID')
    aws_secret_access_key = Stemcell::Builder::validate_env('AWS_SECRET_ACCESS_KEY')
    aws_region = Stemcell::Builder::validate_env('AWS_REGION')

    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    vmx_version_dir = Stemcell::Builder::validate_env_dir('VMX_VERSION_DIR')

    version = File.read(File.join(version_dir, 'number')).chomp
    vmx_version = File.read(File.join(vmx_version_dir, 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf("bosh-windows-stemcell")


    vmx = S3::Vmx.new(
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key,
      aws_region: aws_region,
      input_bucket: Stemcell::Builder::validate_env('INPUT_BUCKET'),
      output_bucket: Stemcell::Builder::validate_env('OUTPUT_BUCKET'),
      vmx_cache_dir: Stemcell::Builder::validate_env('VMX_CACHE_DIR')
    )


    source_path = vmx.fetch(vmx_version)

    vsphere = Stemcell::Builder::VSphere.new(
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '8'),
      source_path: source_path,
      agent_commit: agent_commit,
      administrator_password: Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD'),
      product_key: Stemcell::Builder::validate_env('PRODUCT_KEY'),
      owner: Stemcell::Builder::validate_env('OWNER'),
      organization: Stemcell::Builder::validate_env('ORGANIZATION'),
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      version: version
    )

    vsphere.build
    s3_client = S3::Client.new(
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key,
      aws_region: aws_region
    )

    pattern = File.join(output_directory, "*.tgz").gsub('\\', '/')
    stemcell = Dir.glob(pattern)[0]
    s3_client.put(Stemcell::Builder::validate_env("OUTPUT_BUCKET"),File.basename(stemcell),stemcell)
  end
end
