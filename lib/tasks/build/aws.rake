require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build AWS Stemcell'
  task :aws do
    build_root = File.expand_path("../../../../build", __FILE__)

    version = File.read(File.join(build_root, 'version', 'number')).chomp
    agent_commit = File.read(File.join(build_root, 'compiled-agent', 'sha')).chomp
    base_amis = JSON.parse(
      File.read(
        Dir.glob(File.join(build_root, 'base-amis', 'base-amis-*.json'))[0]
      ).chomp
    )

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    aws_builder = Stemcell::Builder::Aws.new(
      agent_commit: agent_commit,
      amis: base_amis,
      aws_access_key: ENV.fetch("AWS_ACCESS_KEY"),
      aws_secret_key: ENV.fetch("AWS_SECRET_KEY"),
      os: ENV.fetch("OS_VERSION"),
      output_directory: output_directory,
      packer_vars: {},
      version: version
    )

    begin
      aws_builder.build
    rescue => e
      puts "Failed to build stemcell: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end
end
