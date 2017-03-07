#!/usr/bin/env ruby

require 'open3'
require 'fileutils'

def exec_command(cmd)
  Open3.popen2(cmd) do |stdin, out, wait_thr|
    out.each_line do |line|
      puts line
    end
    exit_status = wait_thr.value
    if exit_status != 0
      raise "error running command: #{cmd}"
    end
  end
end

FileUtils.mkdir_p(File.join("stemcell-builder","build"))
FileUtils.cp_r("windows-stemcell-dependencies",File.join("stemcell-builder","build","windows-stemcell-dependencies"))
FileUtils.cp_r("vmx-version",File.join("stemcell-builder","build","vmx-version"))

Dir.chdir "stemcell-builder" do
  exec_command("bundle install")
  exec_command("rake build:vsphere_add_updates")
end
