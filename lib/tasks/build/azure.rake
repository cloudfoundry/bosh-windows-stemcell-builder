require "rspec/core/rake_task"
require "json"

namespace :build do
  desc "Build Azure Stemcell"
  task :azure do
    base_dir_location = ENV.fetch("BUILD_BASE_DIR", "../../../../")
    base_dir = File.expand_path(base_dir_location, __FILE__)

    File.join(base_dir, "build")
    version_dir = Stemcell::Builder.validate_env_dir("VERSION_DIR")

    version = File.read(File.join(version_dir, "number")).chomp

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    # Check required variables
    Stemcell::Builder.validate_env("BASE_IMAGE")
    Stemcell::Builder.validate_env("BASE_IMAGE_OFFER")

    # Log in to the az CLI in order to create a signed URL later in the process
    output, status = Open3.capture2e("az", "login", "--service-principal", "-u", Stemcell::Builder.validate_env("CLIENT_ID"), "-p", Stemcell::Builder.validate_env("CLIENT_SECRET"), "-t", Stemcell::Builder.validate_env("TENANT_ID"))
    if !status.success?
      raise "Unable to log into az CLI:\n#{output}"
    end

    azure_builder = Stemcell::Builder::Azure.new(
      packer_vars: {},
      version: version,
      os: Stemcell::Builder.validate_env("OS_VERSION"),
      output_directory: output_directory,
      client_id: Stemcell::Builder.validate_env("CLIENT_ID"),
      client_secret: Stemcell::Builder.validate_env("CLIENT_SECRET"),
      tenant_id: Stemcell::Builder.validate_env("TENANT_ID"),
      subscription_id: Stemcell::Builder.validate_env("SUBSCRIPTION_ID"),
      resource_group_name: Stemcell::Builder.validate_env("RESOURCE_GROUP_NAME"),
      storage_account: Stemcell::Builder.validate_env("STORAGE_ACCOUNT"),
      location: Stemcell::Builder.validate_env("LOCATION"),
      vm_size: Stemcell::Builder.validate_env("VM_SIZE"),
      publisher: Stemcell::Builder.validate_env("PUBLISHER"),
      offer: Stemcell::Builder.validate_env("OFFER"),
      sku: Stemcell::Builder.validate_env("SKU"),
      vm_prefix: ENV.fetch("VM_PREFIX", ""),
      mount_ephemeral_disk: ENV.fetch("MOUNT_EPHEMERAL_DISK", "false")
    )

    azure_builder.build
  end
end
