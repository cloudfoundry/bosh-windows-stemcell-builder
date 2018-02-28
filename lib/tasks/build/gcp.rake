require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build GCP Stemcell'
  task :gcp do
    build_dir = File.expand_path("../../../../build", __FILE__)

    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    base_image_dir = Stemcell::Builder::validate_env_dir('BASE_IMAGE_DIR')

    version = File.read(File.join(version_dir, 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp
    gcp_image = JSON.parse(
      File.read(
        Dir.glob(File.join(base_image_dir, 'base-gcp-image-*.json'))[0]
      ).chomp
    )
    source_image = gcp_image["base_image"]
    image_family = gcp_image["image_family"]

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    gcp_builder = Stemcell::Builder::Gcp.new(
      account_json: Stemcell::Builder::validate_env('ACCOUNT_JSON'),
      agent_commit: agent_commit,
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      source_image: source_image,
      image_family: image_family,
      version: version,
      vm_prefix: ENV.fetch('VM_PREFIX', '').empty? ? 'packer' : ENV['VM_PREFIX']
    )

    gcp_builder.build
  end
end
