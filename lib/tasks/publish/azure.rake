require 'rspec/core/rake_task'
require 'json'
require_relative '../../stemcell/publisher/azure'

require_relative '../../exec_command'

namespace :publish do
  namespace :staging do
    desc 'Stage an image to the Azure marketplace'
    task :azure do
      container_root = File.expand_path('../../../../..', __FILE__)
      version = File.read(File.join(container_root, 'version', 'number')).chomp
      # Get the container path for sas create
      uri_filename = "bosh-stemcell-*-azure-vhd-uri.txt"
      image_url = File.read(Dir.glob(File.join(container_root, 'azure-base-vhd-uri', uri_filename)).first).chomp
      container_path = (image_url.match %r{(Microsoft\.Compute/Images/.*vhd)})[0]

      publisher = Stemcell::Publisher::Azure.new(
        version: Stemcell::Manifest::Azure.format_version(version),
        sku: ENV['SKU'],
        api_key: ENV['API_KEY'],
        azure_storage_account: ENV['AZURE_STORAGE_ACCOUNT'],
        azure_storage_access_key: ENV['AZURE_STORAGE_ACCESS_KEY'],
        azure_tenant_id: ENV['AZURE_TENANT_ID'],
        azure_client_id: ENV['AZURE_CLIENT_ID'],
        azure_client_secret: ENV['AZURE_CLIENT_SECRET'],
        container_name: ENV['CONTAINER_NAME'],
        container_path: container_path
      )
      publisher.stage
    end
  end

  namespace :production do
    desc 'Publish an image to the Azure marketplace'
    task :azure do
      publisher = Stemcell::Publisher::Azure.new(
        api_key: ENV['API_KEY']
      )
      publisher.publish
    end
  end

  namespace :finalize do
    desc 'Wait for finalizing an image to the Azure marketplace'
    task :azure do
      publisher = Stemcell::Publisher::Azure.new(
        api_key: ENV['API_KEY']
      )
      publisher.finalize
    end
  end
end
