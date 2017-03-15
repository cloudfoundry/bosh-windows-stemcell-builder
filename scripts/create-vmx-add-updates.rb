#!/usr/bin/env ruby

require 'open3'
require 'fileutils'

require_relative '../lib/exec_command'
require_relative '../lib/zip_file'

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
FileUtils.cp_r("windows-stemcell-dependencies",File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("vmx-version",File.join("stemcell-builder","build","vmx-version"))

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake package:psmodules")
  exec_command("rake build:vsphere_add_updates")
end
