require 'aws-sdk'
require_relative 'exec_command'

module S3
  class Client
    def initialize(endpoint: "")
      Aws.use_bundled_cert!
      Aws.config.update(force_path_style: true)
      if (endpoint.to_s.empty?)
        @s3 = Aws::S3::Client.new()
      else
        @s3 = Aws::S3::Client.new(endpoint: endpoint)
      end
      @s3_resource = Aws::S3::Resource.new(client: @s3)
    end
    def get(bucket,key,file_name)
      bucket, key = rationalize(bucket, key)
      puts "Downloading the #{key} from #{bucket} to #{file_name}"
      path = File.dirname(file_name)
      FileUtils.mkdir_p(path)
      File.open(file_name, 'wb') do |file|
        @s3.get_object({ bucket:bucket , key:key, response_target: file })
      end
      puts "Finished Downloading the #{key} from #{bucket} to #{file_name}"
    end
    def put(bucket,key,file_name)
      bucket, key = rationalize(bucket, key)
      puts "Uploading the #{file_name} to #{bucket}:#{key}"
      @s3_resource.bucket(bucket).object(key).upload_file(file_name)
      puts "Finished uploading the #{file_name} to #{bucket}:#{key}"
    end
    def list(bucket)
      bucket, prefix = rationalize(bucket, '')
      puts "Listing bucket #{bucket} with prefix #{prefix}"
      resp = @s3.list_objects({
        bucket: bucket,
        delimiter: '/',
        prefix: prefix
      })
      resp.to_h[:contents].map { |x| x[:key] }
    end
    def clear(bucket)
      puts "Clearing bucket #{bucket}"
      @s3_resource.bucket(bucket).clear!
      puts "Finished: clearing bucket #{bucket}"
    end
    private
      # Our ci passes the bucket and key as bucket: bucket/path/to/file,
      # key: some-filename
      def rationalize(bucket, key)
        new_bucket, folder = bucket.split('/', 2)
        new_key = folder ? [folder, key].join('/') : key
        return new_bucket, new_key
      end
  end

  class Vmx
    def initialize(
      input_bucket:, output_bucket:,vmx_cache_dir:, endpoint: "")
      @client = S3::Client.new(endpoint: endpoint)
      @input_bucket = input_bucket
      @output_bucket = output_bucket
      @vmx_cache_dir = vmx_cache_dir
    end

    def fetch(version)
      version = version.scan(/(\d+)\./).flatten.first

      Dir.foreach(@vmx_cache_dir) do |path|
        if /^\d+$/.match(path)
          if path < version
            puts "Deleting old cache dir #{File.join(@vmx_cache_dir, path)}"
            FileUtils.rm_rf(File.join(@vmx_cache_dir, path))
          end
        elsif vmx_version = /vmx-v([\d]+).tgz/.match(path)
          if vmx_version[1] < version
            puts "Deleting old cache file #{File.join(@vmx_cache_dir, path)}"
            FileUtils.rm(File.join(@vmx_cache_dir, path))
          end
        end
      end

      vmx_tarball = File.join(@vmx_cache_dir,"vmx-v#{version}.tgz")
      puts "Checking for #{vmx_tarball}"
      if !File.exist?(vmx_tarball)
        @client.get(@input_bucket,"vmx-v#{version}.tgz",vmx_tarball)
      else
        puts "VMX file #{vmx_tarball} found in cache."
      end

      # Find the vmx directory matching version, untar if not cached
      vmx_dir=File.join(@vmx_cache_dir,version)
      puts "Checking for #{vmx_dir}"
      if !Dir.exist?(vmx_dir)
        FileUtils.mkdir_p(vmx_dir)
        exec_command("tar -xzvf #{vmx_tarball} -C #{vmx_dir}")
      else
        puts "VMX dir #{vmx_dir} found in cache."
      end

      find_vmx_file(vmx_dir)
    end

    def put(vmx_dir, version)
      version = version.scan(/(\d+)\./).flatten.first
      version = (version.to_i + 1).to_s
      vmx_tarball = File.join(@vmx_cache_dir,"vmx-v#{version}.tgz")
      Dir.chdir(vmx_dir) do
        exec_command("tar -czvf #{vmx_tarball} *")
      end
      @client.put(@output_bucket, "vmx-v#{version}.tgz", vmx_tarball)
    end

    private

    def find_vmx_file(dir)
      pattern = File.join(dir, "*.vmx").gsub('\\', '/')
      files = Dir.glob(pattern)
      if files.length == 0
        raise "No vmx files in directory: #{dir}"
      end
      if files.length > 1
        raise "Too many vmx files in directory: #{files}"
      end
      return files[0]
    end
  end

  def self.test_upload_permissions(bucket, endpoint="")
    puts "Testing upload permissions for #{bucket}"
    tempfile = Tempfile.new("stemcell-permissions-tempfile")
    s3_client = Client.new(endpoint: endpoint)
    s3_client.put(bucket, 'test-upload-permissions', tempfile.path)
    tempfile.unlink
  end
end
