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
