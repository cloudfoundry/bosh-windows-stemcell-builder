require 'rspec/core/rake_task'
require 'json'

require_relative '../../exec_command'
require_relative '../../zip_file'

namespace :package do
    task :agent do
        build_dir = File.expand_path('../../../../build', __FILE__)
        agent_dir = File.join(build_dir,'compiled_agent')
        deps_dir = File.join(agent_dir,'deps')

        FileUtils.mkdir_p(agent_dir)
        FileUtils.mkdir_p(deps_dir)

        ENV['GOPATH'] = Dir.pwd
        Dir.chdir(File.join('src', 'github.com', 'cloudfoundry' ,'bosh-agent')) do
            ENV['GOOS'] = 'windows'
            exec_command("go build -o #{File.join(agent_dir,'bosh-agent.exe')} main/agent.go")
            exec_command("go build -o #{File.join(deps_dir,'pipe.exe')} jobsupervisor/pipe/main.go")
            exec_command("git rev-parse HEAD > #{File.join(agent_dir,'sha')}")
            fixtures = File.join(Dir.pwd, "integration","windows","fixtures")
            deps_files = ['bosh-blobstore-dav.exe',
                          'bosh-blobstore-s3.exe',
                          'job-service-wrapper.exe',
                          'tar.exe',
                          'zlib1.dll']
            deps_files.each do |dep_file|
                FileUtils.cp(File.join(fixtures, dep_file), File.join(deps_dir, dep_file))
            end
            agent_files = ['service_wrapper.exe','service_wrapper.xml']
            agent_files.each do |agent_file|
                FileUtils.cp(File.join(fixtures, agent_file), File.join(agent_dir, agent_file))
            end
        end
        ZipFile::Generator.new(agent_dir,File.join(build_dir,"agent.zip")).write()
    end
end
