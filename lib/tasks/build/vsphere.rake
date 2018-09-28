require 'rspec/core/rake_task'
require 'json'
require 'fileutils'
require 'tempfile'
require_relative '../../s3'
require_relative '../../file_helper'
require_relative '../../stemcell/builder/vsphere'


STDOUT.sync = true
STDERR.sync = true

namespace :build do
  desc 'Apply Windows Updates for VMX'
  task :vsphere_add_updates do
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    vmx_version = File.read(File.join(version_dir, 'number')).chomp
    output_bucket = Stemcell::Builder::validate_env("OUTPUT_BUCKET")

    S3.test_upload_permissions(output_bucket)

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf(output_directory)

    vmx = S3::Vmx.new(
      input_bucket: Stemcell::Builder::validate_env("INPUT_BUCKET"),
      output_bucket: output_bucket,
      vmx_cache_dir: Stemcell::Builder::validate_env("VMX_CACHE_DIR"),
      endpoint: ENV["S3_ENDPOINT"]
    )

    source_path = vmx.fetch(vmx_version)

    vsphere = Stemcell::Builder::VSphereAddUpdates.new(
      administrator_password: Stemcell::Builder::validate_env("ADMINISTRATOR_PASSWORD"),
      source_path: source_path,
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '8'),
      output_directory: output_directory,
      packer_vars: {},
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      http_proxy: ENV.fetch('UPDATES_HTTP_PROXY', ''),
      https_proxy: ENV.fetch('UPDATES_HTTPS_PROXY', ''),
      bypass_list: ENV.fetch('UPDATES_PROXY_BYPASS_LIST', '')
    )

    vsphere.build
    vmx.put(output_directory, vmx_version)
  end

  desc 'Build VSphere patchfile and create stemcell with it'
  task :vsphere_patchfile do
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    version = File.read(File.join(version_dir, 'number')).chomp

    output_directory = Stemcell::Builder::validate_env('OUTPUT_DIR') # packer-output must not exist before packer is run!
    signature_path = File.join(output_directory, 'signature')

    image_bucket = Stemcell::Builder::validate_env('VHD_VMDK_BUCKET')
    patch_output_bucket = Stemcell::Builder::validate_env('PATCH_OUTPUT_BUCKET')
    cache_dir = Stemcell::Builder::validate_env('CACHE_DIR')

    S3.test_upload_permissions(patch_output_bucket, ENV["S3_ENDPOINT"])

    s3_client = S3::Client.new(endpoint: ENV["S3_ENDPOINT"])

    # Get the most recent vhd
    last_file = s3_client.list(image_bucket).select{|file| /.vhd$/.match(file)}.sort.last
    image_basename = File.basename(last_file, File.extname(last_file))

    vhd_version = FileHelper.parse_vhd_version(image_basename)
    patch_path = File.join(File.expand_path(output_directory), "patchfile-#{version}-#{vhd_version}")

    # Look for base vhd and converted vmdk in patchcell worker cache
    vmdk_filename = image_basename + '.vmdk'
    vhd_filename = image_basename + '.vhd'
    vmdk_path = File.join(cache_dir, vmdk_filename)
    vhd_path = File.join(cache_dir, vhd_filename)

    # Download files from S3 if not cached
    if !File.exist?(vmdk_path)
      s3_client.get(image_bucket, vmdk_filename, vmdk_path)
    end
    if !File.exist?(vhd_path)
      s3_client.get(image_bucket, vhd_filename, vhd_path)
    end

    # Setup base vmx file for packer to use
    vmx_template_txt = File.read("resources/old-base-vmx.vmx")
    new_vmx_txt = vmx_template_txt.gsub("INIT_VMDK",vmdk_path)
    config_vmx = Tempfile.new(["config", ".vmx"])
    File.write(config_vmx.path, new_vmx_txt)
    vmx_path = config_vmx.path.gsub("/", "\\")

    vsphere = Stemcell::Builder::VSphere.new(
      mem_size: '16384',
      num_vcpus: '4',
      source_path: vmx_path,
      agent_commit: "",
      administrator_password: Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD'),
      product_key: Stemcell::Builder::validate_env('PRODUCT_KEY'),
      owner: Stemcell::Builder::validate_env('OWNER'),
      organization: Stemcell::Builder::validate_env('ORGANIZATION'),
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      version: version,
      skip_windows_update: false,
      new_password: Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD'),
      http_proxy: ENV.fetch('UPDATES_HTTP_PROXY', ''),
      https_proxy: ENV.fetch('UPDATES_HTTPS_PROXY', ''),
      bypass_list: ENV.fetch('UPDATES_PROXY_BYPASS_LIST', ''),
      build_context: :patchfile,
    )

    vsphere.run_packer
    output_vmdk_path = File.join(output_directory, Dir.entries("#{output_directory}").detect { |e| File.extname(e) == ".vmdk" })

    signature_command = "gordiff signature #{vhd_path} #{signature_path}"
    puts "generating signature: #{signature_command}"
    `#{signature_command}`

    diff_command = "gordiff delta #{signature_path} #{output_vmdk_path} #{patch_path}"
    puts "generating patch: #{diff_command}"
    `#{diff_command}`

    patch_filename = File.basename patch_path
    s3_client.put(patch_output_bucket, patch_filename, patch_path)
  end

  desc 'Build VSphere Stemcell'
  task :vsphere do
    build_dir = File.expand_path("../../../../build", __FILE__)

    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    vmx_version_dir = Stemcell::Builder::validate_env_dir('VMX_VERSION_DIR')
    output_bucket = Stemcell::Builder::validate_env('OUTPUT_BUCKET')

    S3.test_upload_permissions(output_bucket, ENV["S3_ENDPOINT"])

    skip_windows_update = ENV.fetch('SKIP_WINDOWS_UPDATE', 'false').downcase == 'true'

    version = File.read(File.join(version_dir, 'number')).chomp
    vmx_version = File.read(File.join(vmx_version_dir, 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.rm_rf("bosh-windows-stemcell")

    vmx = S3::Vmx.new(
      input_bucket: Stemcell::Builder::validate_env('INPUT_BUCKET'),
      output_bucket: output_bucket,
      vmx_cache_dir: Stemcell::Builder::validate_env('VMX_CACHE_DIR'),
      endpoint: ENV["S3_ENDPOINT"]
    )

    source_path = vmx.fetch(vmx_version)
    administrator_password = Stemcell::Builder::validate_env('ADMINISTRATOR_PASSWORD')

    vsphere = Stemcell::Builder::VSphere.new(
      mem_size: ENV.fetch('MEM_SIZE', '4096'),
      num_vcpus: ENV.fetch('NUM_VCPUS', '4'),
      source_path: source_path,
      agent_commit: agent_commit,
      administrator_password: administrator_password,
      new_password: ENV.fetch('NEW_PASSWORD', administrator_password),
      product_key: ENV['PRODUCT_KEY'],
      owner: Stemcell::Builder::validate_env('OWNER'),
      organization: Stemcell::Builder::validate_env('ORGANIZATION'),
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      version: version,
      enable_rdp: ENV.fetch('ENABLE_RDP', 'false').downcase == 'true',
      skip_windows_update: skip_windows_update,
      http_proxy: ENV.fetch('UPDATES_HTTP_PROXY', ''),
      https_proxy: ENV.fetch('UPDATES_HTTPS_PROXY', ''),
      bypass_list: ENV.fetch('UPDATES_PROXY_BYPASS_LIST', ''),
      mount_ephemeral_disk: ENV.fetch('MOUNT_EPHEMERAL_DISK', 'false'),
    )

    vsphere.build

    pattern = File.join(output_directory, "*.tgz").gsub('\\', '/')
    stemcell = Dir.glob(pattern)[0]
    s3_client = S3::Client.new(endpoint: ENV["S3_ENDPOINT"])
    s3_client.put(Stemcell::Builder::validate_env("OUTPUT_BUCKET"),File.basename(stemcell),stemcell)
  end
end
