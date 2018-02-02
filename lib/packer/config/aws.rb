require 'securerandom'

module Packer
  module Config
    class Aws < Base
      def initialize(aws_access_key, aws_secret_key, regions, output_directory, os)
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @regions = regions
        @output_directory = output_directory
        @os = os
      end

      def builders
        builders = []
        @regions.each do |region|
          builders.push(
            'name' => "amazon-ebs-#{region['name']}",
            'type' => 'amazon-ebs',
            'access_key' => @aws_access_key,
            'secret_key' => @aws_secret_key,
            'region' => region['name'],
            'source_ami' => region['base_ami'],
            'instance_type' => instance_type,
            'ami_name' => "BOSH-#{SecureRandom.uuid}-#{region['name']}",
            'vpc_id' => region['vpc_id'],
            'subnet_id' => region['subnet_id'],
            'associate_public_ip_address' => true,
            'communicator' => 'winrm',
            'winrm_username' => 'Administrator',
            'winrm_timeout' => '1h',
            'user_data_file' => 'scripts/aws/setup_winrm.txt',
            'security_group_id' => region['security_group'],
            'ami_groups' => 'all',
            'ssh_keypair_name' => 'packer_ci',
            'ssh_private_key_file' => '../packer-ci-private-key/key'
          )
        end
        builders
      end

      def provisioners
        [
          Base.pre_provisioners(@os, iaas: 'aws'),
          Provisioners.install_agent('aws').freeze,
          Provisioners.download_windows_updates(@output_directory).freeze,
          Base.post_provisioners('aws', @os)
        ].flatten
      end

      private
        def instance_type
          if @os == 'windows2016'
            return 'm5.large'
          end

          return 'm4.xlarge'
        end
    end
  end
end
