require 'rspec/core/rake_task'
require 'json'
require 'fileutils'

require_relative '../../exec_command'

def windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
end
namespace :package do
    desc 'package bosh-windows-acceptance-tests (BWATS) config.json'
    task :bwats do |t|
	required_vars = [
	    'BOSH_CA_CERT', 'BOSH_CLIENT', 'BOSH_CLIENT_SECRET',
	    'BOSH_TARGET', 'STEMCELL_OS',
	    'STEMCELL_PATH', 'AZ', 'VM_TYPE', 'VM_EXTENSIONS', 'NETWORK'
	]
	missing_vars = false
	required_vars.each do |var|
	    unless ENV[var]
		unless missing_vars
		    puts 'Error:'
		    missing_vars = true
		end
		puts "Missing required environment variable: #{var}"
	    end
	end

	if missing_vars
	    raise 'missing environment variables'
	end
	root_dir = File.expand_path('../../../..', __FILE__)
	build_dir = File.join(root_dir,'build')
	config = {
	    'bosh' => {
		'ca_cert' => ENV['BOSH_CA_CERT'],
		'client' => ENV['BOSH_CLIENT'],
		'client_secret' => ENV['BOSH_CLIENT_SECRET'],
		'target' => ENV['BOSH_TARGET']
	    },
	    'stemcell_path' => File.absolute_path(ENV['STEMCELL_PATH']),
	    'stemcell_os' => ENV['STEMCELL_OS'],
	    'az' => ENV['AZ'],
	    'vm_type' => ENV['VM_TYPE'],
	    'vm_extensions' => ENV['VM_EXTENSIONS'],
	    'network' => ENV['NETWORK'],
	    'mount_ephemeral_disk' => ENV['TEST_EPHEMERAL_DISK'] == 'true'
	}
	FileUtils.mkdir_p build_dir
	File.open(File.join(build_dir,'config.json'), 'w') { |file| file.write(JSON.pretty_generate(config)) }
	ginkgo_dir = File.join(
	    'github.com', 'cloudfoundry-incubator',
	    'bosh-windows-acceptance-tests', 'vendor', 'github.com',
	    'onsi', 'ginkgo', 'ginkgo'
	)
	ginkgo = File.join(build_dir, windows? ? 'gingko.exe' : 'ginkgo')

	ENV["GOPATH"] = root_dir
        exec_command("go build -o #{ginkgo} #{ginkgo_dir}")
    end
end
