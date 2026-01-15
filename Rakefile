$LOAD_PATH << File.join(File.dirname(__FILE__), "lib")

require "output"
require "s3"
require "stemcell/builder"

import "lib/tasks/build/aws.rake"
import "lib/tasks/build/azure.rake"
import "lib/tasks/build/gcp.rake"

import "lib/tasks/label/aws.rake"
import "lib/tasks/label/gcp.rake"

import "lib/tasks/publish/azure.rake"
import "lib/tasks/publish/gcp.rake"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: [:standard, :spec]
