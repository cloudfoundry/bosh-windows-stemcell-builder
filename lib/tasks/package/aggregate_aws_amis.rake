require 'rspec/core/rake_task'

namespace :package do
		desc 'Package all of the manifest amis into a single tar file'
		task :aggregate_aws_amis do
			# Check environment variables
			packer_region = Stemcell::Builder::validate_env('PACKER_REGION')
			aws_access_key_id = Stemcell::Builder::validate_env('AWS_ACCESS_KEY')
			aws_secret_access_key = Stemcell::Builder::validate_env('AWS_SECRET_KEY')
			aws_region = Stemcell::Builder::validate_env('REGION')
			bucket_name = Stemcell::Builder::validate_env('BUCKET_NAME')

			# Make input directory
			input_directory = File.absolute_path("input_amis")
			FileUtils.mkdir_p(input_directory)

			# Download amis
			client = S3::Client.new(aws_access_key_id: aws_access_key_id, aws_secret_access_key: aws_secret_access_key, aws_region: aws_region)

			files = client.list(bucket_name)
			files.each do |file|
				client.get(bucket_name, file, File.join(input_directory, file))
			end

			# Make output directory
			output_directory = File.absolute_path("bosh-windows-stemcell")
			FileUtils.mkdir_p(output_directory)

			# Aggregate amis
			Stemcell::Packager.aggregate_the_amis(input_directory, output_directory, packer_region)
		end
end
