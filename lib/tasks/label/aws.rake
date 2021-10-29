require 'rspec/core/rake_task'
require 'rubygems/package'
require 'yaml'

namespace :aws do
  namespace :label do
    desc 'Label an ami as not published'
    task :for_test do
      packer_output_data = packer_data
      packer_output_ami = packer_output_data['ami_id']
      packer_output_region = packer_output_data['region']

      label_ami(packer_output_ami, packer_output_region, "published", "false")
    end

    desc 'Label an ami as published'
    task :for_production do
      packer_output_data = packer_data
      packer_output_ami = packer_output_data['ami_id']
      packer_output_region = packer_output_data['region']

      label_ami(packer_output_ami, packer_output_region, "published", "true")
    end

    def label_ami(ami, region, key, value)
      exec_command("aws ec2 create-tags --resources #{ami} --region #{region} --tags Key=#{key},Value=#{value}")
    end
  end

  def packer_data
    version_dir = Stemcell::Builder::validate_env_dir('VERSION_DIR')
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer

    # Get packer output data
    version = File.read(File.join(version_dir, 'number')).chomp
    JSON.parse(File.read(File.join(ami_output_directory, "packer-output-ami-#{version}.txt")))
  end
end
