require 'rspec/core/rake_task'
require 'json'
require_relative '../../s3'

namespace :build do
  task :vsphere_add_updates do
    build_dir = File.expand_path("../../../../build", __FILE__)

    vmx_version = File.read(File.join(build_dir, 'vmx-version', 'number')).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf(output_directory)

    vmx = S3::Vmx.new(
      aws_access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
      aws_secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
      aws_region: ENV.fetch("AWS_REGION"),
      input_bucket: ENV.fetch("INPUT_BUCKET"),
      output_bucket: ENV.fetch("OUTPUT_BUCKET"),
      vmx_cache_dir: ENV.fetch("VMX_CACHE_DIR")
    )

    source_path = vmx.fetch(vmx_version)

    vsphere = Stemcell::Builder::VSphereAddUpdates.new(
      administrator_password: ENV.fetch("ADMINISTRATOR_PASSWORD"),
      source_path: source_path,
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '8'),
      output_directory: output_directory,
      packer_vars: {},
    )

    begin
      vsphere.build
      vmx.put(output_directory, vmx_version)
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end
  task :vsphere do
    build_dir = File.expand_path("../../../../build", __FILE__)

    version = File.read(File.join(build_dir, 'version', 'number')).chomp
    vmx_version = File.read(File.join(build_dir, 'vmx-version', 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf("bosh-windows-stemcell")

    vmx = S3::Vmx.new(
      aws_access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
      aws_secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
      aws_region: ENV.fetch("AWS_REGION"),
      input_bucket: ENV.fetch("INPUT_BUCKET"),
      output_bucket: ENV.fetch("OUTPUT_BUCKET"),
      vmx_cache_dir: ENV.fetch("VMX_CACHE_DIR")
    )


    source_path = vmx.fetch(vmx_version)

    vsphere = Stemcell::Builder::VSphere.new(
      administrator_password: ENV.fetch("ADMINISTRATOR_PASSWORD"),
      source_path: source_path,
      product_key: ENV.fetch("PRODUCT_KEY"),
      owner: ENV.fetch("OWNER"),
      organization: ENV.fetch("ORGANIZATION"),
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '8'),
      agent_commit: agent_commit,
      os: ENV.fetch("OS_VERSION"),
      output_directory: output_directory,
      packer_vars: {},
      version: version
    )

    begin
      vsphere.build
      s3_client = S3::Client.new(
        aws_access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
        aws_region: ENV.fetch("AWS_REGION"),
      )

      pattern = File.join(output_directory, "*.tgz").gsub('\\', '/')
      stemcell = Dir.glob(pattern)[0]
      s3_client.put(ENV.fetch("OUTPUT_BUCKET"),File.basename(stemcell),stemcell)
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end
end
