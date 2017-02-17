module Stemcell
  class Packager
    class InvalidImagePathError < ArgumentError
    end

    class InvalidManifestPathError < ArgumentError
    end

    class InvalidApplySpecPathError < ArgumentError
    end

    class InvalidOutputDirError < ArgumentError
    end

    def self.package(iaas, os, is_light, version, image_path, manifest_path,
                     apply_spec_path, output_dir)
      raise InvalidImagePathError unless File.file?(image_path) || is_light
      raise InvalidManifestPathError unless File.file?(manifest_path)
      raise InvalidApplySpecPathError unless File.file?(apply_spec_path)
      raise InvalidOutputDirError unless File.directory?(output_dir)

      stemcell_tarball_file = "bosh-stemcell-#{version}-#{iaas}-#{os}-go_agent.tgz"
      if is_light
        stemcell_tarball_file = "light-#{stemcell_tarball_file}"
      end

      File.open(File.join(output_dir, stemcell_tarball_file), 'wb') do |file|
        Zlib::GzipWriter.wrap(file) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            tar.add_file_simple('stemcell.MF', 0o666, File.size(manifest_path)) do |io|
              File.open(manifest_path, 'rb') { |f| io.write(f.read) }
            end

            if is_light
              tar.add_file_simple('image', 0o666, 0)
            else
              tar.add_file_simple('image', 0o666, File.size(image_path)) do |io|
                File.open(image_path, 'rb') { |f| io.write(f.read) }
              end
            end

            tar.add_file_simple('apply_spec.yml', 0o666, File.size(apply_spec_path)) do |io|
              File.open(apply_spec_path, 'rb') { |f| io.write(f.read) }
            end
          end
        end
      end
    end
  end
end
