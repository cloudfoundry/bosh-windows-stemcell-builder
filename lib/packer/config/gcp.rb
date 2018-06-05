require 'securerandom'

module Packer
  module Config
    class Gcp < Base
      def initialize(account_json:, project_id:, source_image:, image_family:, **args)
        @account_json = account_json
        @project_id = project_id
        @source_image = source_image
        @image_family = image_family
        super(args)
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
            'disk_size' => 100,
            'image_name' =>  "packer-#{Time.now.to_i}",
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
        [
          Base.pre_provisioners(@os, reduce_mtu: true, iaas: 'gcp'),
          Provisioners::lgpo_exe,
          Provisioners.install_agent('gcp', @mount_ephemeral_disk).freeze,
          Provisioners.download_windows_updates(@output_directory).freeze,
          Base.enable_security_patches(@os),
          Base.post_provisioners('gcp')
        ].flatten
      end
    end
  end
end
