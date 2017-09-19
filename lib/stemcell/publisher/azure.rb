require 'net/http'
require 'uri'
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'active_model'
require 'azure_mgmt_resources'
require_relative '../../exec_command'

module Stemcell
  module Publisher
    class Azure
      include ActiveModel::Model

      attr_accessor :version, :sku, :azure_storage_account,
        :azure_storage_access_key, :azure_tenant_id, :azure_client_id,
        :azure_client_secret, :container_name, :container_path

      def print_publishing_instructions
        instructions = <<END
Please login to https://cloudpartner.azure.com
* Click "BOSH Azure Windows Stemcell"
* Click SKUs -> #{sku}
* Click "+ New VM image" at the bottom
* Input version "#{version}" and OS VHD URL "#{sas_uri}"
* Save and click Publish! Remember to click Go Live (in status tab) after it finishes!!
END
        puts instructions
      end

      private
      def sas_uri
        sas_json = create_azure_sas
        sas_info = JSON.parse sas_json
        sas_split = sas_info['url'].split '?'
        sas_split[0] + '/' + container_path + '?' + sas_split[1]
      end

      def create_azure_sas
        now = Time.now.utc
        next_year = (now + 1.year).iso8601
        yesterday = (now - 1.day).iso8601
        login_to_azure
        create_sas_cmd = "azure storage container sas create #{container_name} rl "\
          "--account-name #{azure_storage_account} --account-key #{azure_storage_access_key} "\
          "--start #{yesterday} --expiry #{next_year} --json"
        puts "running azure storage container sas create"
        `#{create_sas_cmd}`
      end

      def login_to_azure
        login_cmd = "azure login --username #{azure_client_id} --password #{azure_client_secret} "\
          "--service-principal --tenant #{azure_tenant_id} --environment AzureCloud"
        puts "running azure login"
        Executor.exec_command_no_output(login_cmd)
      end
    end
  end
end
