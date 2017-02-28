require 'rspec/core/rake_task'
require 'json'

namespace :build do
  task :gcp do
    build_dir = File.expand_path("../../../../build", __FILE__)

    version = File.read(File.join(build_dir, 'version', 'number')).chomp
    agent_commit = File.read(File.join(build_dir, 'compiled-agent', 'sha')).chomp
    base_image = JSON.parse(
      File.read(
        Dir.glob(File.join(build_dir, 'base-gcp-image', 'base-gcp-image-*.json'))[0]
      ).chomp
    )["base_image"]

    FileUtils.mkdir_p(ENV.fetch('OUTPUT_DIR'))

    gcp_builder = Stemcell::Builder::Gcp.new(
      account_json: ENV.fetch("ACCOUNT_JSON"),
      agent_commit: agent_commit,
      os: ENV.fetch("OS_VERSION"),
      output_dir: ENV.fetch("OUTPUT_DIR"),
      packer_vars: {},
      source_image: base_image,
      version: version
    )

    begin
      gcp_builder.build
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
    end
  end
end
