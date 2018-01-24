
require 'rspec/core/rake_task'

namespace :run do
  desc 'removes all files in aws bucket'
  task :cleanup_aws_bucket do
    puts "cleanup aws bucket"
    aws_access_key_id = Stemcell::Builder::validate_env('AWS_ACCESS_KEY')
    aws_secret_access_key = Stemcell::Builder::validate_env('AWS_SECRET_KEY')
    aws_region = Stemcell::Builder::validate_env('REGION')
    bucket_name = Stemcell::Builder::validate_env('BUCKET_NAME')

    client = S3::Client.new()
    client.clear(bucket_name)
  end
end
