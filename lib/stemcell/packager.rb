require 'zlib'
require 'rubygems/package'

module Stemcell
  class Packager
    class InvalidImagePathError < ArgumentError
    end

    class InvalidOutputDirError < ArgumentError
    end

    def self.package_image(image_path:, archive:, output_dir:)
      raise InvalidImagePathError unless File.file?(image_path)
      raise InvalidOutputDirError unless File.directory?(output_dir)

      packaged_image = File.join(output_dir, 'image')
      if archive
        tar_gzip_file(image_path, packaged_image)
      else
        gzip_file(image_path, packaged_image)
      end
      packaged_image
    end

    def self.package(iaas:, os:, is_light:, version:, image_path:, manifest:, apply_spec:, output_dir:)
      raise InvalidImagePathError unless File.file?(image_path) || is_light
      raise InvalidOutputDirError unless File.directory?(output_dir)

      stemcell_tarball_file = "bosh-stemcell-#{version}-#{iaas}-#{os}-go_agent.tgz"
      if is_light
        stemcell_tarball_file = "light-#{stemcell_tarball_file}"
      end

      File.open(File.join(output_dir, stemcell_tarball_file), 'wb') do |file|
        Zlib::GzipWriter.wrap(file) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            tar.add_file_simple('stemcell.MF', 0o666, manifest.length) do |io|
              io.write(manifest)
            end

            if is_light
              tar.add_file_simple('image', 0o666, 0)
            else
              tar.add_file_simple('image', 0o666, File.size(image_path)) do |io|
                File.open(image_path, 'rb') { |f| io.write(f.read) }
              end
            end

            tar.add_file_simple('apply_spec.yml', 0o666, apply_spec.length) do |io|
              io.write(apply_spec)
            end
          end
        end
      end
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
  end
end
