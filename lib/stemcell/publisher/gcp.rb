require 'net/http'
require 'tempfile'
require 'uri'
require 'json'

require_relative '../../exec_command'

module Stemcell
	module Publisher
		class Gcp
			def self.publish(vm_to_add, account_json)
				account_data = JSON.parse(account_json)

				account_email = account_data['client_email']
				project_id = account_data['project_id']

				image_name = File.basename(vm_to_add[:image_url])
				Tempfile.create(['account','.json']) do |f|
					f.write(account_json)
					f.close
					exec_command("gcloud auth activate-service-account --quiet #{account_email} --key-file #{f.path}")
					uri = URI.parse("https://www.googleapis.com/compute/alpha/projects/#{project_id}/global/images/#{image_name}/setIamPolicy")
					puts uri.inspect
					return post(uri, json())
				end
			end

			def self.json
				{
					bindings: [
						{
							role: 'roles/compute.imageUser',
							members: [ 'allAuthenticatedUsers' ]
						}
					]
				}
			end

			# Post request to stage the offer
			def self.post(uri, data)
				http = Net::HTTP.new(uri.host, uri.port)
				http.use_ssl = true
				token = `gcloud auth print-access-token`
				header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{token}"}
				request = Net::HTTP::Post.new(uri.request_uri, header)
				request.body = data.to_json

				response = http.request(request)
				puts "#{response.message}: #{response.body}"
				exit (response.kind_of? Net::HTTPSuccess)
			end
		end
	end
end
