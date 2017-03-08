#!/usr/bin/env ruby

require_relative 'exec-command'
require 'fileutils'

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
FileUtils.cp_r("windows-stemcell-dependencies", File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("compiled-agent", File.join("stemcell-builder","build","compiled-agent"))
FileUtils.cp_r("version", File.join("stemcell-builder","build","version"))
FileUtils.cp_r("base-amis", File.join("stemcell-builder","build","base-amis"))

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake build:aws")
end
