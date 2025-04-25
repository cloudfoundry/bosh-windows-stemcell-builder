require 'zip'
require 'timecop'

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

if ENV.fetch('COVERAGE', false)
  require 'simplecov'
  SimpleCov.start
end

SPEC_ROOT = File.dirname(__FILE__).freeze
REPO_ROOT = Pathname(SPEC_ROOT).parent

def fixture_path(*parts)
  File.join(SPEC_ROOT, 'fixtures', *parts)
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end
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

# require stemcell class
require 'stemcell/packager'
require 'stemcell/builder'
