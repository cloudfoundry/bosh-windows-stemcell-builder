#!/usr/bin/env ruby

require 'open3'
require 'fileutils'

require_relative 'exec-command'
require_relative 'bundle-bosh-psmodules'

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
zip_bosh_psmodules(File.join("stemcell-builder","build","bosh-psmodules.zip"))
FileUtils.cp_r("windows-stemcell-dependencies",File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("vmx-version",File.join("stemcell-builder","build","vmx-version"))

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake build:vsphere_add_updates")
end
