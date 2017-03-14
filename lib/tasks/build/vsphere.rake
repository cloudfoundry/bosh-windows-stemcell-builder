require 'rspec/core/rake_task'
require 'json'
require_relative '../../s3'

namespace :build do
  task :package_vsphere, [:ova_file_name, :output_directory, :version, :agent_commit] do |t, args|
    ova_file_name = args[:ova_file_name]
    output_directory = args[:output_directory]
    version = args[:version]
    agent_commit = args[:agent_commit]
    os = 'windows2012R2'
    iaas = 'vsphere-esxi'

    image_path = File.join(output_directory, 'image')

    Stemcell::Packager.removeNIC(ova_file_name)
    Stemcell::Packager.gzip_file(ova_file_name, image_path)
    sha1_sum = Digest::SHA1.file(image_path).hexdigest

    manifest = Stemcell::Manifest::VSphere.new(version, sha1_sum, os).dump
    apply_spec = Stemcell::ApplySpec.new(agent_commit).dump

    Stemcell::Packager.package(
      iaas: iaas,
      os: os,
      is_light: false,
      version: version,
      image_path: image_path,
      manifest: manifest,
      apply_spec: apply_spec,
      output_directory: output_directory
    )
  end
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
