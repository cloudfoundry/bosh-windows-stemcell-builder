require 'rspec/core/rake_task'
require 'json'
require_relative '../../s3'

namespace :build do
  task :vsphere_add_updates do
    build_dir = File.expand_path("../../../../build", __FILE__)

    vmx_version = File.read(File.join(build_dir, 'vmx-version', 'number')).chomp

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

    vsphere = Stemcell::Builder::VSphereAddUpdates.new(
      administrator_password: ENV.fetch("ADMINISTRATOR_PASSWORD"),
      source_path: source_path,
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '6'),
      os: ENV.fetch("OS_VERSION"),
      output_directory: "bosh-windows-stemcell",
      packer_vars: {},
    )

    begin
      vsphere.build
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
      num_vcpus: ENV.fetch('NUM_VCPUS', '6'),
      agent_commit: agent_commit,
      os: ENV.fetch("OS_VERSION"),
      output_directory: "bosh-windows-stemcell",
      packer_vars: {},
      version: version
    )

    begin
      vsphere.build
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end
end
