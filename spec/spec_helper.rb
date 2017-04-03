EMPTY_FILE_SHA = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
require 'zip'

# Mock web requests
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  # config.order = :random

  Kernel.srand config.seed
end

def tgz_extract(file_path, out_dir)
  File.open(file_path, 'rb') do |file|
    Zlib::GzipReader.wrap(file) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          next unless entry.file?

          entry_path = File.join(out_dir, entry.full_name)
          FileUtils.mkdir_p(File.dirname(entry_path))

          File.open(entry_path, 'wb') do |f|
            f.write(entry.read)
          end

          File.chmod(entry.header.mode, entry_path)
        end
      end
    end
  end
end

def read_from_tgz(path, filename)
  contents = ''
  tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(path))
  tar_extract.rewind
  tar_extract.each do |entry|
    if entry.full_name.include?(filename)
      contents = entry.read
    end
  end
  tar_extract.close
  contents
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

# require stemcell class
require 'stemcell/packager'
require 'stemcell/builder'
