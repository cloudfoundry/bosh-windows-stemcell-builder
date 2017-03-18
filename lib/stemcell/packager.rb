require 'zlib'
require 'rubygems/package'

module Stemcell
  class Packager
    class InvalidImagePathError < ArgumentError
    end

    class InvalidOutputDirError < ArgumentError
    end

    def self.package_image(image_path:, archive:, output_directory:)
      raise InvalidImagePathError unless File.file?(image_path)
      raise InvalidOutputDirError unless File.directory?(output_directory)

      packaged_image = File.join(output_directory, 'image')
      if archive
        tar_gzip_file(image_path, packaged_image)
      else
        gzip_file(image_path, packaged_image)
      end
      packaged_image
    end

    def self.package(iaas:, os:, is_light:, version:, image_path:, manifest:, apply_spec:, output_directory:)
      raise InvalidImagePathError unless File.file?(image_path) || is_light
      raise InvalidOutputDirError unless File.directory?(output_directory)

      stemcell_tarball_file = "bosh-stemcell-#{version}-#{iaas}-#{os}-go_agent.tgz"
      if is_light
        stemcell_tarball_file = "light-#{stemcell_tarball_file}"
      end

      File.open(File.join(output_directory, stemcell_tarball_file), 'wb') do |file|
        Zlib::GzipWriter.wrap(file) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            tar.add_file_simple('stemcell.MF', 0o666, manifest.length) do |io|
              io.write(manifest)
            end

            if is_light
              tar.add_file_simple('image', 0o666, 0)
            else
              tar.add_file_simple('image', 0o666, File.size(image_path)) do |io|
                image = File.open(image_path,'rb')
                while(cur_line = image.gets)
                  io.write(cur_line)
                end
                image.close
              end
            end

            tar.add_file_simple('apply_spec.yml', 0o666, apply_spec.length) do |io|
              io.write(apply_spec)
            end
          end
        end
      end

      sha = Digest::SHA1.file(File.join(output_directory, stemcell_tarball_file)).hexdigest
      filename = File.join(output_directory, stemcell_tarball_file + ".sha")
      File.write(filename, sha)
    end

    def self.gzip_file(name, output)
      Zlib::GzipWriter.open(output) do |gz|
       File.open(name) do |fp|
         while chunk = fp.read(32 * 1024) do
           gz.write chunk
         end
       end
       gz.close
      end
    end

    def self.tar_gzip_file(name, output)
      File.open(output, 'wb') do |file|
        Zlib::GzipWriter.wrap(file) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            tar.add_file_simple(File.basename(name), 0o666, File.size(name)) do |io|
              File.open(name, 'rb') { |f| io.write(f.read) }
            end
          end
        end
      end
    end

    def self.removeNIC(ova_file_name)
      Dir.mktmpdir do |dir|
        exec_command("tar -xf #{ova_file_name} -C #{dir}")

        ovf_file = File.open(find_ovf_file(dir))
        f = Nokogiri::XML(ovf_file)
        nics = f.css("VirtualHardwareSection Item").select { |x| x.to_s =~ /Ethernet/i }
        if nics.first
          nics.first.remove
        end
        File.write(ovf_file, f.to_s)
        ovf_file.close
        Dir.chdir(dir) do
          exec_command("tar -cf #{ova_file_name} *")
        end
      end
    end

    def self.find_ovf_file(dir)
      pattern = File.join(dir, "*.ovf").gsub('\\', '/')
      files = Dir.glob(pattern)
      if files.length == 0
        raise "No ovf files in directory: #{dir}"
      end
      if files.length > 1
        raise "Too many ovf files in directory: #{files}"
      end
      return files[0]
    end

    def self.exec_command(cmd)
      STDOUT.sync = true
      Open3.popen2(cmd) do |stdin, out, wait_thr|
        out.each_line do |line|
          puts line
        end
        exit_status = wait_thr.value
        if exit_status != 0
          raise "error running command: #{cmd}"
        end
      end
    end

  end
end
