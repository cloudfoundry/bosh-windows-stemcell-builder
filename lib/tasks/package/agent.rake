require 'rspec/core/rake_task'
require 'json'

require_relative '../../exec_command'
require_relative '../../zip_file'

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

        FileUtils.mkdir_p(agent_dir_destination)
        FileUtils.mkdir_p(deps_dir)

        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-s3-cli', 's3cli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-s3.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-gcs-cli', 'bosh-gcscli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-gcs.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'blobstore-dav-cli', 'davcli-*-windows-amd64.exe')).first, File.join(deps_dir, 'bosh-blobstore-dav.exe'))
        FileUtils.cp(Dir.glob(File.join(ci_root_dir, 'windows-bsdtar', 'tar-*.exe')).first, File.join(deps_dir, 'tar.exe'))
        FileUtils.cp(File.join(ci_root_dir, 'windows-winsw', 'WinSW.NET461.exe'), File.join(deps_dir, 'job-service-wrapper.exe'))
        FileUtils.cp(File.join(ci_root_dir, 'windows-winsw', 'WinSW.NET461.exe'), File.join(agent_dir_destination, 'service_wrapper.exe'))

        FileUtils.cp(Dir.glob(File.join(agent_dir_location, 'bosh-agent*.exe')).first, File.join(agent_dir_destination, 'bosh-agent.exe'))
        FileUtils.cp(Dir.glob(File.join(agent_dir_location, 'bosh-agent-pipe*.exe')).first, File.join(deps_dir, 'pipe.exe'))
        FileUtils.cp(File.join(agent_dir_location, 'git-sha'), File.join(agent_dir_destination, 'sha'))
        FileUtils.cp(File.join(agent_dir_location, 'service_wrapper.xml'), File.join(agent_dir_destination, 'service_wrapper.xml'))

        output = File.join(build_dir,"agent.zip")
        FileUtils.rm_rf(output)
        ZipFile::Generator.new(agent_dir_destination, output).write
    end
end
