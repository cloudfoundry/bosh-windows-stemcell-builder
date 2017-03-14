require 'rspec/core/rake_task'
require_relative 'lib/stemcell/builder'
import 'lib/tasks/build/aws.rake'
import 'lib/tasks/build/gcp.rake'
import 'lib/tasks/build/vsphere.rake'
import 'lib/tasks/bundle_agent.rake'

namespace :build do
  desc 'Build Azure Stemcell'
  task :azure do
    puts 'build:azure'
  end

  task :openstack do
    puts 'build:openstack'
  end

  task :gcp do
    puts 'build:gcp'
  end

  task :vsphere do
    puts 'build:vsphere'
  end
end

desc 'Bundle BOSH Stemcell Agent and dependencies into agent.zip'
task :bundle_agent do
  puts 'bundle_agent'
end
