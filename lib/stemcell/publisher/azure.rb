require 'net/http'
require 'uri'
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'active_model'

module Stemcell
  module Publisher
    class Azure
      include ActiveModel::Model

      attr_accessor :version, :sku, :api_key, :azure_storage_account,
        :azure_storage_access_key, :azure_tenant_id, :azure_client_id,
        :azure_client_secret, :container_name, :container_path

      def publish
        response = obtain_offer_data(base_url, api_key)
        if response.code != '200'
          raise "could not obtain offer data. expected 200 but got '#{response.code}'"
        end
        update_body = json(response.body)
        response = update_offer(base_url, update_body, api_key)
        if response.code != '200'
          raise "could not update offer data. expected 200 but got '#{response.code}'"
        end
        response = stage_offer(base_url, api_key)
        if response.code != '202'
          raise "could not stage offer. expected 202 but got '#{response.code}'"
        end
      end

      def base_url
        "https://publish.windowsazure.com/publishers/pivotal/offers/#{sku}"
      end

      def json(response_string)
        response_json = JSON.parse(response_string)
        json = response_json['Offer']

        vm_images = json['VirtualMachineImagesByServicePlan'][sku]['VirtualMachineImages']

        converted_vm_to_add = {
          'VersionId' => version,
          'VersionLabel' => version,
          'OsImageUrl' => sas_uri,
          'isLocked' => false,
          'DataDiskUrlsByLunNumber' => {}
        }
        vm_images.push(converted_vm_to_add)
        json.to_json
      end

      def sas_uri
        sas_json = create_azure_sas
        sas_info = JSON.parse sas_json
        sas_split = sas_info['url'].split '?'
        sas_split[0] + container_path + sas_split[1]
      end

      def create_azure_sas
        now = Time.now.utc
        next_year = (now + 1.year).iso8601
        yesterday = (now - 1.day).iso8601
        login_cmd = "azure login --username #{azure_client_id} --password #{azure_client_secret} "\
          "--service-principal --tenant #{azure_tenant_id} --environment AzureCloud"
        puts "running azure login"
        `#{login_cmd}`
        create_sas_cmd = "azure storage container sas create #{container_name} rl "\
          "--account-name #{azure_storage_account} --account-key #{azure_storage_access_key} "\
          "--start #{yesterday} --expiry #{next_year} --json"
        puts "running azure storage container sas create"
        `#{create_sas_cmd}`
      end

      # Helper Methods

      # Add request headers
      def add_headers!(req, api_key)
        req['Accept'] = 'application/json'
        req['Authorization'] =  "WAMP apikey=#{api_key}"
        req['X-Protocol-Version'] = '2'
        req['Content-Type'] = 'application/json'
      end

      # Get request to obtain offer data
      def obtain_offer_data(url, api_key)
        uri = URI(url)
        req = Net::HTTP::Get.new(uri)
        add_headers!(req, api_key)
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(req)
        end
        puts "response: #{response.body}"
        return response
      end

      # Post request to update the offer with latest image
      def update_offer(url, body, api_key)
        uri = URI(url+'update')
        req = Net::HTTP::Post.new(uri)
        req.body = body
        add_headers!(req, api_key)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(req)
        end
        puts "response: #{response.body}"
        return response
      end

      # Post request to stage the offer
      def stage_offer(url, api_key)
        uri = URI(url+'stage')
        req = Net::HTTP::Post.new(uri)
        add_headers!(req, api_key)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(req)
        end
        puts "response: #{response.body}"
        return response
      end

    end
  end
end
