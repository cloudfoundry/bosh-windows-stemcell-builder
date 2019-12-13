require 'rspec/core/rake_task'
require 'json'

require_relative '../../zip_file'

namespace :package do
    desc 'Package BOSH psmodules into bosh-psmodules.zip'
    task :psmodules do
        base_dir_location = ENV.fetch('BUILD_BASE_DIR', '../../../../')
        base_dir = File.expand_path(base_dir_location, __FILE__)

        build_dir = File.join(base_dir, 'build')

        psmodules_location = ENV.fetch('BOSH_PSMODULES_DIR', '../../../../bosh-psmodules')
        psmodules_dir = File.join(psmodules_location,'modules')

        FileUtils.mkdir_p(build_dir)

        output = File.join(build_dir,"bosh-psmodules.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(psmodules_dir, output).write()
    end
end
