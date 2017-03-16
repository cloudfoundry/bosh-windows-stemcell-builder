require 'rspec/core/rake_task'
require 'json'

require_relative '../../zip_file'

namespace :package do
    desc 'Package BOSH psmodules into bosh-psmodules.zip'
    task :psmodules do
        build_dir = File.expand_path('../../../../build', __FILE__)
        psmodules_dir = File.join(Dir.pwd,'bosh-psmodules','modules')

        FileUtils.mkdir_p(build_dir)

        output = File.join(build_dir,"bosh-psmodules.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(psmodules_dir, output).write()
    end
end
