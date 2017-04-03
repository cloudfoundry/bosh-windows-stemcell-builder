require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build Azure Stemcell'
  task :azure do
    build_root = File.expand_path('../../../../build', __FILE__)

    version = File.read(File.join(build_root, 'version', 'number')).chomp
    agent_commit = File.read(File.join(build_root, 'compiled-agent', 'sha')).chomp

    output_directory = File.absolute_path('bosh-windows-stemcell')
    FileUtils.mkdir_p(output_directory)

    azure_builder = Stemcell::Builder::Azure.new(
      agent_commit: agent_commit,
      os: ENV.fetch('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      version: version,
      client_id: ENV.fetch('CLIENT_ID'),
      client_secret: ENV.fetch('CLIENT_SECRET'),
      tenant_id: ENV.fetch('TENANT_ID'),
      subscription_id: ENV.fetch('SUBSCRIPTION_ID'),
      object_id: ENV.fetch("OBJECT_ID"),
      resource_group_name: ENV.fetch('RESOURCE_GROUP_NAME'),
      storage_account: ENV.fetch('STORAGE_ACCOUNT'),
      location: ENV.fetch('LOCATION'),
      vm_size: ENV.fetch('VM_SIZE'),
      publisher: ENV.fetch('PUBLISHER'),
      offer: ENV.fetch('OFFER'),
      sku: ENV.fetch('SKU'),
      admin_password: ENV.fetch("ADMIN_PASSWORD")
    )

    azure_builder.build
    puts "bosh-windows-stemcell:"
    puts `ls #{output_directory}`
  end
end
