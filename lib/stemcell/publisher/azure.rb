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

      def finalize
        status = poll_status('production')
        if status == 'Listed'
          puts "Successfully published offer"
        else
          raise "could not publish offer. status is #{status}"
        end
      end

      def publish
        status = poll_status('staging')
        if status == 'Staged'
          post(base_url+'list', '')
        else
          raise "could not stage offer. status is #{status}"
        end
      end

      def stage
        response = get(base_url)
        unless response.kind_of? Net::HTTPSuccess
          raise "could not obtain offer data. expected 200 but got '#{response.code}'"
        end
        update_body = json(response.body)
        response = post(base_url+'update', update_body)
        unless response.kind_of? Net::HTTPSuccess
          raise "could not update offer data. expected 200 but got '#{response.code}'"
        end
        response = post(base_url+'stage', '')
        unless response.kind_of? Net::HTTPSuccess
          raise "could not stage offer. expected 202 but got '#{response.code}'"
        end
      end

      def base_url
        "https://publish.windowsazure.com/publishers/pivotal/offers/bosh-windows-server/"
      end

      private

        def poll_status(mode)
          status = ''
          while true
            response = get(base_url+'progress')
            unless response.kind_of? Net::HTTPSuccess
              raise "could not obtain progress data. expected 200 but got '#{response.code}'"
            end
            response_body = JSON.parse(response.body)
            status = response_body[mode]['State']
            puts "#{mode} status: #{status}"
            break if status != 'InProgress'
            puts "#{Time.now} Starting to sleep for an hour"
            sleep 60 * 60
            puts "#{Time.now} Done sleeping"
          end
          return status
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
          puts "adding new vm image:"
          puts converted_vm_to_add.inspect
          json.to_json
        end

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

        def get(url)
          puts "url: #{url}"
          uri = URI(url)
          req = Net::HTTP::Get.new(uri)
          add_headers!(req, api_key)
          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            http.request(req)
          end
          puts "response: #{response.body}"
          return response
        end

        def post(url, body)
          puts "url: #{url}"
          uri = URI(url)
          req = Net::HTTP::Post.new(uri)
          req.body = body
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
