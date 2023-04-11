require 'rspec/core/rake_task'
require 'json'
require 'tempfile'

namespace :build do
  class FailedAMICopyError < RuntimeError
  end
  class FailedAMIValidationError < RuntimeError
  end

  desc 'Build AWS Stemcell'
  task :aws do
    # Check required environment variables
    base_amis_dir = Stemcell::Builder::validate_env_dir('BASE_AMIS_DIR')
    region = Stemcell::Builder::validate_env('PACKER_REGION')
    output_bucket = Stemcell::Builder::validate_env('OUTPUT_BUCKET_NAME')

    S3.test_upload_permissions(output_bucket)

    # Setup dir where we will save the stemcell tgz
    output_directory = File.absolute_path("bosh-windows-stemcell")
    FileUtils.mkdir_p(output_directory)
    # Setup dir where we will save the packer output ami
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR')

    # Get input amis from Amazon
    base_ami = JSON.parse(
      File.read(
        Dir.glob(File.join(base_amis_dir, 'base-amis-*.json'))[0]
      ).chomp,
      symbolize_names: true
    )
    raise "No ami information for #{region}" unless base_ami[:name] == region
    puts "Found ami information for: #{region}"

    # Create stemcell
    aws_builder = get_aws_builder(output_directory, region, base_ami)
    aws_builder.build_from_packer(ami_output_directory)

    # Upload the final tgz to S3
    artifact_name = Stemcell::Packager::get_tar_files_from(output_directory).first

    s3_client = S3::Client.new()
    s3_client.put(output_bucket, artifact_name, File.join(output_directory, artifact_name))
  end


  desc 'Validate packer output AMI is available'
  task :validate_ami do
    # Check required environment variables
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer

    # Get packer output data
    version = File.read(File.join(version_dir, 'number')).chomp
    packer_output_data = JSON.parse(File.read(File.join(ami_output_directory, "packer-output-ami-#{version}.txt")))
    packer_output_ami = packer_output_data['ami_id']
    packer_output_region = packer_output_data['region']

    puts "Waiting for #{packer_output_ami} to become available..."

    ami_pending = true
    while ami_pending do

      ec2_describe_command = "aws ec2 describe-images --image-ids #{packer_output_ami} " \
         "--region #{packer_output_region} --filters Name=state,Values=available,failed"
      ami_description = JSON.parse(exec_command(ec2_describe_command))

      if ami_description['Images'].count == 1
        ami_pending = false
        if ami_description['Images'][0]['State'] == "available"
          puts "AMI #{packer_output_ami} is available"
        else
          puts "AWS failed to create AMI #{packer_output_ami}"
          raise FailedAMIValidationError.new("AWS failed to create AMI #{packer_output_ami}")
        end
      end
    end
  end

  desc 'Copy AMI from source to remaining regions'
  task :aws_ami do
    # Check required environment variables
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer
    destination_regions = Stemcell::Builder::validate_env('REGIONS').split(',')
    default_stemcell_directory = Stemcell::Builder::validate_env_dir('DEFAULT_STEMCELL_DIR') # contains the stemcell tgz created with packer
    copied_amis = Array.new

    # Setup dir where we will save the individual regional stemcell tgz
    copied_stemcells_directory = File.absolute_path("copied-regional-stemcells")
    FileUtils.mkdir_p(copied_stemcells_directory)

    FileUtils.cp(Dir[File.join(default_stemcell_directory, "*.tgz")].first, copied_stemcells_directory)
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
      copied_amis.push new_ami

      # Create stemcell tgz
      aws_builder = get_aws_builder(copied_stemcells_directory, destination_region)
      aws_builder.build([new_ami])
    end

    #Copy region is asynchronous and takes time. Need to poll each ami and make them public once they are available
    while copied_amis.count > 0 do
      copied_amis.delete_if do |copied_ami|

        #Check to see if ami is available or failed
        ec2_describe_command = "aws ec2 describe-images --image-ids #{copied_ami['ami_id']} " \
          "--region #{copied_ami['region']} --filters Name=state,Values=available,failed"
        ami_description = JSON.parse(exec_command(ec2_describe_command))

        if ami_description['Images'].count == 1
          if ami_description['Images'][0]['State'] == "available"
            #Make available ami public
            puts "Making #{copied_ami['ami_id']} public"
            ec2_public_command = "aws ec2 modify-image-attribute --image-id #{copied_ami['ami_id']} " \
                "--launch-permission '{\"Add\":[{\"Group\":\"all\"}]}' --region #{copied_ami['region']}"
            exec_command(ec2_public_command)
          else
            puts "AMI #{copied_ami['ami_id']} has failed to be copied to region #{copied_ami['region']}"
            raise FailedAMICopyError.new("Failed to copy AMI #{copied_ami['ami_id']}")
          end
          true
        end
      end
    end

  end

  desc 'Aggregate AMIs into stemcell manifest'
  task :aws_aggregate do
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer

    output_directory = File.absolute_path("bosh-windows-stemcell")
    copied_stemcells_directory = File.absolute_path("copied-regional-stemcells")
    FileUtils.mkdir_p(output_directory)
    FileUtils.mkdir_p(copied_stemcells_directory)

    version = File.read(File.join(version_dir, 'number')).chomp
    packer_output_data = JSON.parse(File.read(File.join(ami_output_directory, "packer-output-ami-#{version}.txt")))
    packer_output_region = packer_output_data['region']

    stemcell_directories = Stemcell::Builder::validate_env('COPIED_STEMCELL_DIRECTORIES').split(',')
    stemcell_directories.each do |stemcell_dir|
      FileUtils.cp_r(Dir[File.join(stemcell_dir, "*.tgz")], copied_stemcells_directory)
    end


    Stemcell::Packager.aggregate_the_amis(copied_stemcells_directory, output_directory, packer_output_region)

    stemcell_tarball_file = Dir[File.join(output_directory, "*.tgz")].first
    Stemcell::Packager.generate_sha(stemcell_tarball_file, output_directory)
  end
end

def get_aws_builder(output_directory, region, base_ami = '')
  version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')

  base_dir_location = ENV.fetch('BUILD_BASE_DIR', '../../../../')
  base_dir = File.expand_path(base_dir_location, __FILE__)

  build_dir = File.join(base_dir, 'build')
  agent_dir = File.join(build_dir,'compiled-agent')
  version = File.read(File.join(version_dir, 'number')).chomp
  agent_commit = File.read(File.join(agent_dir, 'sha')).chomp

  Stemcell::Builder::Aws.new(
    agent_commit: agent_commit,
    ami: base_ami,
    aws_access_key: Stemcell::Builder::validate_env('AWS_ACCESS_KEY'),
    aws_secret_key: Stemcell::Builder::validate_env('AWS_SECRET_KEY'),
    aws_role_arn: ENV['AWS_ROLE_ARN'],
    os: Stemcell::Builder::validate_env('OS_VERSION'),
    output_directory: output_directory,
    packer_vars: {},
    version: version,
    region: region,
    vm_prefix: ENV.fetch('VM_PREFIX', ''),
    mount_ephemeral_disk: ENV.fetch('MOUNT_EPHEMERAL_DISK', 'false')
  )
end
