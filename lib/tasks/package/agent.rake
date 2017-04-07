require 'rspec/core/rake_task'
require 'json'

require_relative '../../exec_command'
require_relative '../../zip_file'

def get_agent_version
    semver = `git describe --tags`.chomp[1..-1]
    go_ver=`go version`.split[2].chomp
    git_rev = `git rev-parse --short HEAD`.chomp
    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    "#{semver}-#{git_rev}-#{timestamp}-#{go_ver}"
end

namespace :package do
    desc 'Package BOSH Agent and dependencies into agent.zip'
    task :agent do
        build_dir = File.expand_path('../../../../build', __FILE__)
        agent_dir = File.join(build_dir,'compiled-agent')
        deps_dir = File.join(agent_dir,'deps')

        FileUtils.mkdir_p(agent_dir)
        FileUtils.mkdir_p(deps_dir)

        ENV['GOPATH'] = Dir.pwd
        Dir.chdir(File.join('src', 'github.com', 'cloudfoundry' ,'bosh-agent')) do
            ENV['GOOS'] = 'windows'
            ENV['GOARCH'] = 'amd64'
            version_file = File.join('main', 'version.go')
            File.write(version_file, File.open(version_file, &:read).gsub('[DEV BUILD]', get_agent_version))
            exec_command("go build -o #{File.join(agent_dir,'bosh-agent.exe')} github.com/cloudfoundry/bosh-agent/main")
            exec_command("go build -o #{File.join(deps_dir,'pipe.exe')} jobsupervisor/pipe/main.go")
            exec_command("git rev-parse HEAD > #{File.join(agent_dir,'sha')}")
            fixtures = File.join(Dir.pwd, "integration","windows","fixtures")
            deps_files = ['bosh-blobstore-dav.exe',
                          'bosh-blobstore-s3.exe',
                          'job-service-wrapper.exe',
                          'tar.exe']
            deps_files.each do |dep_file|
                FileUtils.cp(File.join(fixtures, dep_file), File.join(deps_dir, dep_file))
            end
            agent_files = ['service_wrapper.exe','service_wrapper.xml']
            agent_files.each do |agent_file|
                FileUtils.cp(File.join(fixtures, agent_file), File.join(agent_dir, agent_file))
            end
        end
        output = File.join(build_dir,"agent.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(agent_dir,output).write()
    end
end
