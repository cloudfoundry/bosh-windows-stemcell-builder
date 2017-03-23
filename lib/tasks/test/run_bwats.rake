require 'rspec/core/rake_task'
require 'mkmf'
require 'json'
require 'fileutils'
require 'tempfile'

ROOTPATH = File.join(File.dirname(__FILE__), '../../../')

require_relative File.join(ROOTPATH, 'lib', 'exec_command.rb')

def install_ginkgo
  ginkgo_dir = File.join(
    ROOTPATH, "src", "github.com", "cloudfoundry-incubator",
    "bosh-windows-acceptance-tests", "vendor", "github.com",
    "onsi", "ginkgo", "ginkgo"
  )
  Dir.chdir(ginkgo_dir) do
    exec_command("go install")
  end
end

def check_environment
  required_vars = [
    'BOSH_CA_CERT', 'BOSH_CLIENT', 'BOSH_CLIENT_SECRET',
    'DIRECTOR_IP', 'DIRECTOR_UUID', 'STEMCELL_NAME',
    'STEMCELL_PATH', 'AZ', 'VM_TYPE','NETWORK'
  ]
  missing_vars = false
  required_vars.each do |var|
    unless ENV[var]
      unless missing_vars
        puts 'Error:'
        missing_vars = true
      end
      puts "  missing required environment variable: #{var}"
    end
  end

  if missing_vars
    puts 'environment check failed: exiting 1'
    exit 1
  end
end

def windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
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
    exec_command("gcloud compute ssh --quiet bosh-bastion --zone=us-east1-d "\
      "--project=#{project_id} -- -f -N -L 25555:#{ENV['DIRECTOR_IP']}:25555")

    ENV['DIRECTOR_IP']='localhost'
  end
end

namespace :test do
  desc 'Run BWATS'
  task :run_bwats do |t|
    check_environment

    ENV['GOPATH'] = ROOTPATH # bosh-windows-stemcell-builder

    puts "adding local 'bin' directory to path: #{File.join(ROOTPATH, 'bin')}"
    ENV['PATH'] = "#{ENV['PATH']}#{File::PATH_SEPARATOR}#{File.join(ROOTPATH, 'bin')}"

    unless ENV['IAAS'].nil? || ENV['IAAS'].empty?
      if ENV['IAAS'] == 'gcp'
        setup_gcp_ssh_tunnel
      else
        puts "ignoring IAAS environment key: #{ENV['IAAS']}"
      end
    end

    if !find_executable('go')
      throw 'go is required to run this test: download from https://golang.org/dl/'
    end
    if !find_executable('ginkgo')
      puts 'installing ginkgo'
      install_ginkgo
    end

    test_path = File.join(
      ROOTPATH, 'src', 'github.com', 'cloudfoundry-incubator',
      'bosh-windows-acceptance-tests'
    )
    puts "running bosh-windows-acceptance-tests tests: #{test_path}"

    exec_command("ginkgo -r -v #{test_path}")
  end
end
