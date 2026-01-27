require "aws-sdk-s3"
require_relative "output"
require_relative "exec_command"

module S3
  class Client
    def initialize(endpoint: "")
      Aws.use_bundled_cert!
      Aws.config[:s3] = {force_path_style: true}
      @s3 = if endpoint.to_s.empty?
        Aws::S3::Client.new
      else
        Aws::S3::Client.new(endpoint: endpoint)
      end
      @s3_resource = Aws::S3::Resource.new(client: @s3)
    end

    def get(bucket, key, file_name)
      bucket, key = rationalize(bucket, key)
      Output.say "Downloading the #{key} from #{bucket} to #{file_name}"
      path = File.dirname(file_name)
      FileUtils.mkdir_p(path)
      File.open(file_name, "wb") do |file|
        @s3.get_object({bucket: bucket, key: key, response_target: file})
      end
      Output.say "Finished Downloading the #{key} from #{bucket} to #{file_name}"
    end

    def put(bucket, key, file_name)
      bucket, key = rationalize(bucket, key)
      Output.say "Uploading the #{file_name} to #{bucket}:#{key}"
      @s3_resource.bucket(bucket).object(key).upload_file(file_name)
      Output.say "Finished uploading the #{file_name} to #{bucket}:#{key}"
    end

    def list(bucket)
      bucket, prefix = rationalize(bucket, "")
      Output.say "Listing bucket #{bucket} with prefix #{prefix}"
      resp = @s3.list_objects({
        bucket: bucket,
        delimiter: "/",
        prefix: prefix
      })
      resp.to_h[:contents].map { |x| x[:key] }
    end

    def clear(bucket)
      Output.say "Clearing bucket #{bucket}"
      @s3_resource.bucket(bucket).clear!
      Output.puts "Finished: clearing bucket #{bucket}"
    end

    private

    # Our ci passes the bucket and key as bucket: bucket/path/to/file,
    # key: some-filename
    def rationalize(bucket, key)
      new_bucket, folder = bucket.split("/", 2)
      new_key = folder ? [folder, key].join("/") : key

      [new_bucket, new_key]
    end
  end

  def self.test_upload_permissions(bucket, endpoint = "")
    Output.say "Testing upload permissions for #{bucket}"
    tempfile = Tempfile.new("stemcell-permissions-tempfile")
    s3_client = Client.new(endpoint: endpoint)
    s3_client.put(bucket, "test-upload-permissions", tempfile.path)
    tempfile.unlink
  end
end
