require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build Azure Stemcell'
  task :azure do
    build_root = File.expand_path('../../../../build', __FILE__)
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    os_version = Stemcell::Builder::validate_env('OS_VERSION')
    client_id = Stemcell::Builder::validate_env('CLIENT_ID')
    client_secret = Stemcell::Builder::validate_env('CLIENT_SECRET')
    tenant_id = Stemcell::Builder::validate_env('TENANT_ID')
    subscription_id = Stemcell::Builder::validate_env('SUBSCRIPTION_ID')
    object_id = Stemcell::Builder::validate_env('OBJECT_ID'),
    resource_group_name = Stemcell::Builder::validate_env('RESOURCE_GROUP_NAME')
    storage_account = Stemcell::Builder::validate_env('STORAGE_ACCOUNT')
    location = Stemcell::Builder::validate_env('LOCATION')
    vm_size = Stemcell::Builder::validate_env('VM_SIZE')
    publisher = Stemcell::Builder::validate_env('PUBLISHER')
    offer = Stemcell::Builder::validate_env('OFFER')
    sku = Stemcell::Builder::validate_env('SKU')
    admin_password = Stemcell::Builder::validate_env('ADMIN_PASSWORD')

    version = File.read(File.join(version_dir, 'number')).chomp
    agent_commit = File.read(File.join(build_root, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path('bosh-windows-stemcell')
    FileUtils.mkdir_p(output_directory)

    azure_builder = Stemcell::Builder::Azure.new(
      agent_commit: agent_commit,
      os: os_version,
      output_directory: output_directory,
      packer_vars: {},
      version: version,
      client_id: client_id,
      client_secret: client_secret,
      tenant_id: tenant_id,
      subscription_id: subscription_id,
      object_id: object_id,
      resource_group_name: resource_group_name,
      storage_account: storage_account,
      location: location,
      vm_size: vm_size,
      publisher: publisher,
      offer: offer,
      sku: sku,
      admin_password: admin_password
    )

    azure_builder.build
  end
end
