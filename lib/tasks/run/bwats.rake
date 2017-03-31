require 'rspec/core/rake_task'
require 'mkmf'
require 'json'
require 'fileutils'
require 'tempfile'
require 'socket'
require 'timeout'

require_relative '../../exec_command'


def windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
end

def port_open?(port)
  Timeout::timeout(5) do
    begin
      TCPSocket.new('127.0.0.1', port).close
      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
      false
    end
  end
rescue Timeout::Error
  false
end


def setup_gcp_ssh_tunnel
  throw "GCP tests must be run on linux" if windows?

  unless ENV['ACCOUNT_JSON']
    throw 'ACCOUNT_JSON environment variable is required for GCP'
  end

  account_json = JSON.parse(ENV['ACCOUNT_JSON'])
  account_email = account_json['client_email']
  project_id = account_json['project_id']

  Tempfile.create('bwats-') do |f|
    f.write(ENV['ACCOUNT_JSON'])
    f.close
    exec_command("gcloud auth activate-service-account --quiet #{account_email} --key-file #{f.path}")

    FileUtils.mkdir_p("/root/.ssh")
    job = fork do
      exec_command("gcloud compute ssh --quiet bosh-bastion --zone=us-east1-d --project=#{project_id} -- -f -N -L 25555:#{ENV['BOSH_PRIVATE_IP']}:25555")
    end
    Process.detach(job)

    tries = 0
    while true
      if tries > 3
        Process.kill 9,job
        raise 'failed to create SSH tunnel'
      end
      if port_open?(25555)
        puts 'SSH tunnel succeeded'
        break
      end
      tries += 1
      sleep 15
    end
  end
end

namespace :run do
  desc 'Run bosh-windows-acceptance-tests (BWATS)'
  task :bwats, [:iaas] do |t, args|
    if args[:iaas] == 'gcp'
      setup_gcp_ssh_tunnel
    else
      puts "ignoring IAAS environment key: #{ENV['IAAS']}"
    end

    root_dir = File.expand_path('../../../..', __FILE__)
    build_dir = File.join(root_dir,'build')

    ginkgo = File.join(build_dir, windows? ? 'gingko.exe' : 'ginkgo')
    test_path = File.join(
      root_dir, 'src', 'github.com', 'cloudfoundry-incubator',
      'bosh-windows-acceptance-tests'
    )
    ENV["CONFIG_JSON"] = args.extras[0] || File.join(build_dir,"config.json")
    ENV["GOPATH"] = root_dir
    exec_command("#{ginkgo} -r -v #{test_path}")
  end
end
