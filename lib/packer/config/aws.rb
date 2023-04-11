require 'securerandom'

module Packer
  module Config
    class Aws
      def initialize(aws_access_key:, aws_secret_key:, aws_role_arn: nil, region:, os:, output_directory:, version:, vm_prefix: '', mount_ephemeral_disk: false)
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @aws_role_arn = aws_role_arn
        @region = region
        @os = os
        @output_directory = output_directory
        @version = version
        @vm_prefix = vm_prefix.empty? ? 'packer' : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
      end

      def builders
        stemcell_builder_dir = File.expand_path('../../../../', __FILE__)
        packer_ci_private_key_location = ENV.fetch('PACKER_CI_PRIVATE_KEY_LOCATION', '../packer-ci-private-key/key')
        #TODO deleteme. Added to resolve a winrm with newer source ami (ami-0060daada4a15ad8a)
        source_ami = @region[:base_ami]
        if @os == 'windows2012R2'
          source_ami = "ami-067ff23da8261d1c7"
        end
        [
          {
            name: "amazon-ebs-#{@region[:name]}",
            type: 'amazon-ebs',
            access_key: @aws_access_key,
            secret_key: @aws_secret_key,
            region: @region[:name],
            source_ami: source_ami,
            instance_type: instance_type,
            ami_name: "BOSH-#{SecureRandom.uuid}-#{@region[:name]}",
            vpc_id: @region[:vpc_id],
            subnet_id: @region[:subnet_id],
            associate_public_ip_address: true,
            launch_block_device_mappings: launch_block_device_mappings,
            communicator: 'winrm',
            winrm_username: 'Administrator',
            winrm_timeout: '1h',
            user_data_file: File.join(stemcell_builder_dir, 'scripts', 'aws', 'setup_winrm.txt'),
            security_group_id: @region[:security_group],
            ami_groups: 'all',
            ssh_keypair_name: 'packer_ci',
            ssh_private_key_file: packer_ci_private_key_location,
            run_tags: { Name: "#{@vm_prefix}-#{Time.now.to_i}" }
          }.merge(assume_role_parameters)
        ]
      end

      def provisioners
        ProvisionerFactory.new(@os, 'aws', @mount_ephemeral_disk, @version).dump
      end

      def dump
        JSON.dump(
            'builders' => builders,
            'provisioners' => provisioners
        )
      end

      private

      def assume_role_parameters
        return {} if @aws_role_arn.nil? || @aws_role_arn.empty?
        { assume_role: { role_arn: @aws_role_arn } }
      end

      def instance_type
        type = 'm4.large'

        if @os == 'windows2012R2'
          type = 'm4.xlarge'
        end

        type
      end

      def launch_block_device_mappings
        volume_size = 30
        volume_size = 128 if @os == 'windows2012R2'

        [
            {
                'device_name': '/dev/sda1',
                'volume_size': volume_size,
                'volume_type': 'gp2',
                'delete_on_termination': true,
            }
        ]
      end
    end
  end
end
