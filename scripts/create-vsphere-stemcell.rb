#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/exec_command'

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
FileUtils.cp_r("windows-stemcell-dependencies",File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("version",File.join("stemcell-builder","build","version"))
FileUtils.cp_r("vmx-version",File.join("stemcell-builder","build","vmx-version"))

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake package:agent")
  exec_command("rake package:psmodules")
  exec_command("rake build:vsphere")
end
