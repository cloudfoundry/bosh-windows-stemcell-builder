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

def download_gcs_cli(destination)
    current_version="0.0.6"
    system("curl -L -o #{File.join(destination, 'bosh-blobstore-gcs.exe')} https://s3.amazonaws.com/bosh-gcscli/bosh-gcscli-#{current_version}-windows-amd64.exe")
end

namespace :package do
    desc 'Package BOSH Agent and dependencies into agent.zip'
    task :agent do
        base_dir_location = ENV.fetch('BUILD_BASE_DIR', '../../../../')
        agent_dir_location = File.expand_path(ENV.fetch('BOSH_AGENT_DIR'))

        base_dir = File.expand_path(base_dir_location, __FILE__)
        build_dir = File.join(base_dir, 'build')
        agent_dir_destination = File.join(build_dir,'compiled-agent')

        deps_dir = File.join(agent_dir_destination,'deps')

        stemcell_builder_dir = File.expand_path('../../../../', __FILE__)

        FileUtils.mkdir_p(agent_dir_destination)
        FileUtils.mkdir_p(deps_dir)

        ENV['GOPATH'] = stemcell_builder_dir
        Dir.chdir(File.join(stemcell_builder_dir, 'src', 'github.com', 'cloudfoundry' ,'bosh-agent')) do
            ENV['GOOS'] = 'windows'
            ENV['GOARCH'] = 'amd64'
            version_file = File.join('main', 'version.go')
            File.write(version_file, File.open(version_file, &:read).gsub('[DEV BUILD]', get_agent_version))
            # exec_command("go build -o #{File.join(agent_dir_destination,'bosh-agent.exe')} github.com/cloudfoundry/bosh-agent/main")
            FileUtils.cp(File.join(agent_dir_location,'bosh-agent.exe'), agent_dir_destination)
            exec_command("go build -o #{File.join(deps_dir,'pipe.exe')} jobsupervisor/pipe/main.go")
            exec_command("git rev-parse HEAD > #{File.join(agent_dir_destination,'sha')}")
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
                FileUtils.cp(File.join(fixtures, agent_file), File.join(agent_dir_destination, agent_file))
            end
        end
        download_gcs_cli(deps_dir)
        output = File.join(build_dir,"agent.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(agent_dir_destination, output).write()
    end
end
