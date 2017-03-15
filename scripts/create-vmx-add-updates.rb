#!/usr/bin/env ruby

require 'open3'
require 'fileutils'

require_relative 'exec-command'
require_relative '../lib/zip'

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
FileUtils.cp_r("windows-stemcell-dependencies",File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("vmx-version",File.join("stemcell-builder","build","vmx-version"))

directory = File.join(__dir__,"..","bosh-psmodules","modules")
output = File.join("stemcell-builder","build","bosh-psmodules.zip")
Zip::Generator.new(directory, output).write()

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake build:vsphere_add_updates")
end
