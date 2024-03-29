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

      name = packer_output_data['name']
      version = packer_output_data['version']
      label_ami(packer_output_ami, packer_output_region, "name", "#{name}-#{version}" )
      label_ami(packer_output_ami, packer_output_region, "version", version)
      label_ami(packer_output_ami, packer_output_region, "distro", name )
    end

    desc 'Label an ami as published'
    task :for_production do
      packer_output_data = packer_data
      packer_output_ami = packer_output_data['ami_id']
      packer_output_region = packer_output_data['region']

      label_ami(packer_output_ami, packer_output_region, "published", "true")

      name = packer_output_data['name']
      version = packer_output_data['version']
      label_ami(packer_output_ami, packer_output_region, "name", name )
      label_ami(packer_output_ami, packer_output_region, "version", version)
      label_ami(packer_output_ami, packer_output_region, "distro", "windows" )
    end

    def label_ami(ami, region, key, value)
      exec_command("aws ec2 create-tags --resources #{ami} --region #{region} --tags Key=#{key},Value=#{value}")
    end
  end

  def packer_data
    ami_output_directory = Stemcell::Builder::validate_env_dir('AMIS_DIR') # contains the ami of the image created by packer

    # Get packer output data
    packer_output_file_glob = Dir.glob(File.join(ami_output_directory, "packer-output-ami-*.txt"))
    raise "multiple packer files found" if packer_output_file_glob.length > 1
    raise "no packer file found" if packer_output_file_glob.length == 0

    win_version = "windows-#{packer_output_file_glob.first.split("-")[3].split(".")[0]}"
    version = packer_output_file_glob.first.split("-")[3].split(".")[1]

    JSON.parse(File.read(packer_output_file_glob.first)).merge({"name"=> win_version, "version"=> version })
  end

end
