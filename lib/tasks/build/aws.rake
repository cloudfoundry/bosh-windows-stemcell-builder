require 'rspec/core/rake_task'
require 'json'

namespace :build do
  desc 'Build AWS Stemcell'
  task :aws do
    # Check required environment variables
    base_amis_dir = Stemcell::Builder::validate_env_dir('BASE_AMIS_DIR')
    region = Stemcell::Builder::validate_env('REGION')
    aws_access_key_id = Stemcell::Builder::validate_env('AWS_ACCESS_KEY')
    aws_secret_access_key = Stemcell::Builder::validate_env('AWS_SECRET_KEY')
    aws_region = Stemcell::Builder::validate_env('OUTPUT_BUCKET_REGION')
    output_bucket = Stemcell::Builder::validate_env('OUTPUT_BUCKET_NAME')

    # Setup dir where we will save the stemcell tgz
    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)
    # Setup dir where we will save the packer output ami
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR')

    # Get input amis from Amazon
    base_amis = JSON.parse(
      File.read(
        Dir.glob(File.join(base_amis_dir, 'base-amis-*.json'))[0]
      ).chomp
    ).select { |ami| ami['name'] == region }
    puts "base_amis.count: #{base_amis.count}"

    # Create stemcell
    aws_builder = get_aws_builder(output_directory, region, base_amis)
    aws_builder.build_from_packer(ami_output_directory)

    # Upload the final tgz to S3
    artifact_name = Stemcell::Packager::get_tar_files_from(output_directory).first

    client = S3::Client.new(
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key,
      aws_region: aws_region
    )
    client.put(output_bucket, artifact_name, File.join(output_directory, artifact_name))
  end

  task :aws_ami do
    # Check required environment variables
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer
    default_stemcell_directory = Stemcell::Builder::validate_env_dir('DEFAULT_STEMCELL_DIR') # contains the stemcell tgz created with packer
    destination_regions = Stemcell::Builder::validate_env('REGIONS').split(',')

    # Setup dir where we will save the individual regional stemcell tgz
    copied_stemcells_directory = File.absolute_path("copied-regional-stemcells")
    FileUtils.mkdir_p(copied_stemcells_directory)

    # Directory where the final aggregate light stemcell will be saved
    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)

    # Get packer output data
    version = File.read(File.join(version_dir, 'number')).chomp
    packer_output_data = JSON.parse(File.read(File.join(ami_output_directory, "packer-output-ami-#{version}.txt")))
    packer_output_ami = packer_output_data['ami_id']
    packer_output_region = packer_output_data['region']

    # Get packer output image name from EC2
    ec2_describe_command = "aws ec2 describe-images --image-ids #{packer_output_ami} --region #{packer_output_region}"
    packer_image_data = JSON.parse(exec_command(ec2_describe_command))
    packer_image_name = packer_image_data['Images'][0]['Name']

    # Copy to each region
    puts "destination_regions: #{destination_regions}"
    destination_regions.each do |destination_region|
      new_image_name = packer_image_name.gsub(packer_output_region, destination_region)

      # Copy image
      ec2_copy_command = "aws ec2 copy-image --source-image-id #{packer_output_ami} " \
        "--source-region #{packer_output_region} --region #{destination_region} --name #{new_image_name}"
      copy_data = JSON.parse(exec_command(ec2_copy_command))

      new_ami = {'region' => destination_region, 'ami_id' => copy_data['ImageId']}

      # Create stemcell tgz
      aws_builder = get_aws_builder(copied_stemcells_directory, destination_region)
      aws_builder.build([new_ami])
    end

    # Move the default stemcell into the copied stemcells directory so that it will be aggregated
    FileUtils.cp(Dir[File.join(default_stemcell_directory, "*.tgz")].first, copied_stemcells_directory)

    # Aggregate amis
    Stemcell::Packager.aggregate_the_amis(copied_stemcells_directory, output_directory, packer_output_region)

    # Create stemcell sha file
    stemcell_tarball_file = Dir[File.join(output_directory, "*.tgz")].first
    Stemcell::Packager.generate_sha(stemcell_tarball_file, output_directory)

  end
end

def get_aws_builder(output_directory, region, base_amis=[])
  version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')

  build_dir = File.expand_path('../../../../build', __FILE__)
  agent_dir = File.join(build_dir,'compiled-agent')
  version = File.read(File.join(version_dir, 'number')).chomp
  agent_commit = File.read(File.join(agent_dir, 'sha')).chomp

  Stemcell::Builder::Aws.new(
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
end
