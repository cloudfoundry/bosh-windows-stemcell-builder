require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build AWS Stemcell'
  task :aws do
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    base_amis_dir = Stemcell::Builder::validate_env_dir('BASE_AMIS_DIR')
    region = Stemcell::Builder::validate_env('REGION')

    build_dir = File.expand_path('../../../../build', __FILE__)
    agent_dir = File.join(build_dir,'compiled-agent')
    version = File.read(File.join(version_dir, 'number')).chomp
    agent_commit = File.read(File.join(agent_dir, 'sha')).chomp
    base_amis = JSON.parse(
      File.read(
        Dir.glob(File.join(base_amis_dir, 'base-amis-*.json'))[0]
      ).chomp
    ).select { |ami| ami['name'] == region }
    puts "base_amis.count: #{base_amis.count}"

    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    aws_builder = Stemcell::Builder::Aws.new(
      agent_commit: agent_commit,
      amis: base_amis,
      aws_access_key: Stemcell::Builder::validate_env('AWS_ACCESS_KEY'),
      aws_secret_key: Stemcell::Builder::validate_env('AWS_SECRET_KEY'),
      os: Stemcell::Builder::validate_env('OS_VERSION'),
      output_directory: output_directory,
      packer_vars: {},
      version: version,
      region: region
    )

    aws_builder.build

    # Upload the final tgz to S3
    artifact_name = Stemcell::Packager::get_tar_files_from(output_directory).first

    client = S3::Client.new(
      aws_access_key_id: Stemcell::Builder::validate_env('AWS_ACCESS_KEY'),
      aws_secret_access_key: Stemcell::Builder::validate_env('AWS_SECRET_KEY'),
      aws_region: Stemcell::Builder::validate_env('OUTPUT_BUCKET_REGION')
    )
    client.put(Stemcell::Builder::validate_env('OUTPUT_BUCKET_NAME'), artifact_name, File.join(output_directory, artifact_name))
  end
end
