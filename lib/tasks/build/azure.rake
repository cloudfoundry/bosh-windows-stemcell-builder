require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build Azure Stemcell'
  task :azure do
    build_root = File.expand_path('../../../../build', __FILE__)
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')

    version = File.read(File.join(version_dir, 'number')).chomp
    agent_commit = File.read(File.join(build_root, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path('bosh-windows-stemcell')
    FileUtils.mkdir_p(output_directory)

    # Check required variables
    Stemcell::Builder::validate_env('BASE_IMAGE')
    Stemcell::Builder::validate_env('BASE_IMAGE_OFFER')

    azure_builder = Stemcell::Builder::Azure.new(
      packer_vars: {},
      version: version,
      agent_commit: agent_commit,
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      client_id: Stemcell::Builder::validate_env('CLIENT_ID'),
      client_secret: Stemcell::Builder::validate_env('CLIENT_SECRET'),
      tenant_id: Stemcell::Builder::validate_env('TENANT_ID'),
      subscription_id: Stemcell::Builder::validate_env('SUBSCRIPTION_ID'),
      resource_group_name: Stemcell::Builder::validate_env('RESOURCE_GROUP_NAME'),
      storage_account: Stemcell::Builder::validate_env('STORAGE_ACCOUNT'),
      location: Stemcell::Builder::validate_env('LOCATION'),
      vm_size: Stemcell::Builder::validate_env('VM_SIZE'),
      publisher: Stemcell::Builder::validate_env('PUBLISHER'),
      offer: Stemcell::Builder::validate_env('OFFER'),
      sku: Stemcell::Builder::validate_env('SKU'),
      vm_prefix: ENV.fetch('VM_PREFIX', ''),
      mount_ephemeral_disk: ENV.fetch('MOUNT_EPHEMERAL_DISK', 'false'),
    )

    azure_builder.build
  end
end
