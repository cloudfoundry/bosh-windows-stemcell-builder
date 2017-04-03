require 'securerandom'

module Packer
  module Config
    class Gcp < Base
      def initialize(account_json, project_id, source_image, output_directory)
        @account_json = account_json
        @project_id = project_id
        @source_image = source_image
        @output_directory = output_directory
      end

      def builders
        [
          {
            'type' => 'googlecompute',
            'account_file' => @account_json,
            'project_id' => @project_id,
            'tags' => ['winrm'],
            'source_image' => @source_image,
            'image_family' => 'windows-2012-r2',
            'zone' => 'us-east1-c',
            'disk_size' => 50,
            'image_name' =>  "packer-#{Time.now.to_i}",
            'machine_type' => 'n1-standard-4',
            'omit_external_ip' => false,
            'communicator' => 'winrm',
            'winrm_username' => 'winrmuser',
            'winrm_use_ssl' => false,
            'metadata' => {
              'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/setup-winrm.ps1'
            }
          }
        ]
      end

      def provisioners
        ( Base.instance_method(:pre_provisioners).bind(self).call <<
        [
          Provisioners.install_agent('gcp').freeze,
          Provisioners::INSTALL_CF_FEATURES,
          Provisioners::PROTECT_CF_CELL,
          Provisioners.download_windows_updates(@output_directory).freeze,
          Provisioners::CLEANUP_WINDOWS_FEATURES,
          Provisioners::CLEANUP_ARTIFACTS
        ] <<
        Base.instance_method(:post_provisioners).bind(self).call).flatten
      end
    end
  end
end
