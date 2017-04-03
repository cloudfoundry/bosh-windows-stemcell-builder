require 'net/http'
require 'uri'

module Stemcell
	module Publisher
		class Azure
			def self.publish(vm_to_add, api_key, url)
				offer_data = obtain_offer_data(url, api_key)
				update_body = self.json(offer_data, vm_to_add)
				update_offer(url, update_body, api_key)
				stage_offer(url, api_key)
			end

			def self.json(response_string, vm_to_add)
				response_json = JSON.parse(response_string)
				json = response_json['Offer']

				vm_images = json['VirtualMachineImagesByServicePlan']['2012r2']['VirtualMachineImages']
				converted_vm_to_add = {
					'VersionId' => vm_to_add[:version],
					'VersionLabel' => vm_to_add[:version],
					'OsImageUrl' => vm_to_add[:image_url],
					'isLocked' => false,
					'DataDiskUrlsByLunNumber' => {}
				}
				vm_images.push(converted_vm_to_add)
				json
			end

			# Helper Methods

			# Add request headers
			def self.add_headers!(req, api_key)
				req['Accept'] = 'application/json'
				req['Authorization'] =  "WAMP apikey=#{api_key}"
				req['X-Protocol-Version'] = '2'
				req['Content-Type'] = 'application/json'
			end

			# Get request to obtain offer data
			def self.obtain_offer_data(url, api_key)
				uri = URI(url)
				req = Net::HTTP::Get.new(uri)
				add_headers!(req, api_key)
				response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
					http.request(req)
				end
				return response.body
			end

			# Post request to update the offer with latest image
			def self.update_offer(url, body, api_key)
				uri = URI(url+'update')
				req = Net::HTTP::Post.new(uri)
				req.set_form_data(body)
				add_headers!(req, api_key)

				response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
					http.request(req)
				end
				puts "response: #{response.body}"
			end

			# Post request to stage the offer
			def self.stage_offer(url, api_key)
				uri = URI(url+'stage')
				req = Net::HTTP::Post.new(uri)
				add_headers!(req, api_key)

				response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
					http.request(req)
				end
				puts "response: #{response.body}"
			end

		end
	end
end
