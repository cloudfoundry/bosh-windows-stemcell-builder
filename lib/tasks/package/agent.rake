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
        base_dir_location = ENV.fetch('BUILD_BASE_DIR', '../../../../')
        agent_dir_location = File.expand_path(ENV.fetch('BOSH_AGENT_DIR'))

        base_dir = File.expand_path(base_dir_location, __FILE__)
        ci_root_dir = File.expand_path(File.join(base_dir_location, '..'), __FILE__)
        build_dir = File.join(base_dir, 'build')
        agent_dir_destination = File.join(build_dir,'compiled-agent')

        deps_dir = File.join(agent_dir_destination,'deps')

        stemcell_builder_dir = File.expand_path('../../../../', __FILE__)

        FileUtils.mkdir_p(agent_dir_destination)
        FileUtils.mkdir_p(deps_dir)

        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-s3-cli', 's3cli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-s3.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-gcs-cli', 'bosh-gcscli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-gcs.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-dav-cli', 'davcli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-dav.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'windows-bsdtar', 'tar-*.exe')).first, File.join(deps_dir, 'tar.exe'))
        ENV['GOPATH'] = stemcell_builder_dir
        Dir.chdir(File.join(stemcell_builder_dir, 'src', 'github.com', 'cloudfoundry' ,'bosh-agent')) do
            ENV['GOOS'] = 'windows'
            ENV['GOARCH'] = 'amd64'

            FileUtils.cp(File.join(agent_dir_location,'bosh-agent.exe'), agent_dir_destination)
            exec_command("go build -o #{File.join(deps_dir,'pipe.exe')} jobsupervisor/pipe/main.go")
            exec_command("git rev-parse HEAD > #{File.join(agent_dir_destination,'sha')}")
            fixtures = File.join(Dir.pwd, "integration","windows","fixtures")
            #all the below files being copied out of bosh-agent should probably be auto-bumped.
            FileUtils.cp(File.join(fixtures, 'job-service-wrapper.exe'), File.join(deps_dir, 'job-service-wrapper.exe'))
            agent_files = ['service_wrapper.exe','service_wrapper.xml']
            agent_files.each do |agent_file|
                FileUtils.cp(File.join(fixtures, agent_file), File.join(agent_dir_destination, agent_file))
            end
        end
        output = File.join(build_dir,"agent.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(agent_dir_destination, output).write()
    end
end