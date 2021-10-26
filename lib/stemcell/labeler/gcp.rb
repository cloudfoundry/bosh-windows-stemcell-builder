require_relative '../../exec_command'

module Stemcell
	module Labeler
		class Gcp
			def self.label(image_url, account_json, key, value)
				account_data = JSON.parse(account_json)
				project_id = account_data['project_id']
				image_name = File.basename(image_url)

				Tempfile.create(['account','.json']) do |f|
					f.write(account_json)
					f.close
					exec_command("gcloud auth activate-service-account --quiet --key-file #{f.path}")
					exec_command("gcloud compute images add-labels #{image_name} --labels=#{key}=#{value} --project #{project_id}")
				end
			end
		end
	end
end
