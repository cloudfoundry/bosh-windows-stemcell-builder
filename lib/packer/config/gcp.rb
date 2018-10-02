require 'securerandom'

module Packer
  module Config
    class Gcp
      def initialize(account_json:, project_id:, source_image:, image_family:, os:, output_directory:, vm_prefix: '', mount_ephemeral_disk: false)
        @account_json = account_json
        @project_id = project_id
        @source_image = source_image
        @image_family = image_family
        @os = os
        @output_directory = output_directory
        @vm_prefix = vm_prefix.empty? ? 'packer' : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
      end

      def builders
        [
            {
                'type' => 'googlecompute',
                'account_file' => @account_json,
                'project_id' => @project_id,
                'tags' => ['winrm'],
                'source_image' => @source_image,
                'image_family' => @image_family,
                'zone' => 'us-east1-c',
                'disk_size' => disk_size,
                'image_name' => "packer-#{Time.now.to_i}",
                'machine_type' => 'n1-standard-4',
                'omit_external_ip' => false,
                'communicator' => 'winrm',
                'winrm_username' => 'winrmuser',
                'winrm_use_ssl' => false,
                'winrm_timeout' => '1h',
                'metadata' => {
                    'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/gcp/setup-winrm.ps1',
                    'name' => "#{@vm_prefix}-#{Time.now.to_i}",
                }
            }
        ]
      end

      def provisioners
        ProvisionerFactory.new(@os, 'gcp', @mount_ephemeral_disk).dump
      end

      def dump
        JSON.dump(
            'builders' => builders,
            'provisioners' => provisioners
        )
      end

      private

      def disk_size
        if @os == 'windows2012R2'
          100
        else
          32
        end
      end
    end
  end
end
