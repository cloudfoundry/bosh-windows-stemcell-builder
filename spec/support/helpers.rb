def fixture_path(*parts)
  File.join(SPEC_ROOT, "fixtures", *parts)
end

def tgz_extract(file_path, out_dir)
  File.open(file_path, "rb") do |file|
    Zlib::GzipReader.wrap(file) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          next unless entry.file?

          entry_path = File.join(out_dir, entry.full_name)
          FileUtils.mkdir_p(File.dirname(entry_path))

          File.binwrite(entry_path, entry.read)

          File.chmod(entry.header.mode, entry_path)
        end
      end
    end
  end
end

def read_from_tgz(path, filename)
  Stemcell::Packager.read_from_tgz(path, filename)
end

def tgz_file_list(path)
  file_list = []
  tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(path))
  tar_extract.rewind
  tar_extract.each do |entry|
    file_list << entry.full_name
  end
  file_list
end

def zip_file_list(file_path)
  file_list = []
  Zip::File.open(file_path) do |zip_file|
    # Handle entries one by one
    zip_file.each do |entry|
      file_list << entry.name
    end
  end
  file_list
end
