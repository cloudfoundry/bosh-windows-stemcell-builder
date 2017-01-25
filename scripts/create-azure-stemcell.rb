#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'mkmf'
require 'open3'
require 'pathname'
require 'securerandom'
require 'tmpdir'
require 'tmpdir'
require_relative '../erb_templates/templates.rb'

VERSION = File.read("version/number").chomp

AGENT_PATH = "compiled-agent/agent.zip"
AGENT_DEPS_PATH = "compiled-agent/agent-dependencies.zip"
AGENT_COMMIT = File.read("compiled-agent/sha").chomp

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
CLIENT_ID = ENV.fetch("CLIENT_ID")
CLIENT_SECRET = ENV.fetch("CLIENT_SECRET")
TENANT_ID = ENV.fetch("TENANT_ID")
SUBSCRIPTION_ID = ENV.fetch("SUBSCRIPTION_ID")
OBJECT_ID = ENV.fetch("OBJECT_ID")
ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD")
STORAGE_ACCOUNT = ENV.fetch("STORAGE_ACCOUNT")
RESOURCE_GROUP_NAME= ENV.fetch("RESOURCE_GROUP_NAME")
LOCATION= ENV.fetch("LOCATION")

def parse_disk_uri(line)
  unless line.include?("azure-arm,artifact,0") and line.include?("OSDiskUriReadOnlySas:")
    return
  end
  (line.split '\n').select do |s|
    s.start_with?("OSDiskUriReadOnlySas: ")
  end.first.gsub("OSDiskUriReadOnlySas: ", "")
end

def run_packer(config_path)
  disk_uri=nil

  Dir.chdir(File.dirname(config_path)) do
    command = %{
      packer build \
      -machine-readable \
      -var "client_id=#{CLIENT_ID}" \
      -var "client_secret=#{CLIENT_SECRET}" \
      -var "tenant_id=#{TENANT_ID}" \
      -var "subscription_id=#{SUBSCRIPTION_ID}" \
      -var "object_id=#{OBJECT_ID}" \
      -var "admin_password=#{ADMIN_PASSWORD}" \
      -var "resource_group_name=#{RESOURCE_GROUP_NAME}" \
      -var "storage_account=#{STORAGE_ACCOUNT}" \
      -var "location=#{LOCATION}" \
      #{config_path}
    }

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdout.each_line do |line|
        puts line
        disk_uri ||= parse_disk_uri(line)
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts stderr.readlines
        puts "packer build failed #{exit_status}"
        exit(1)
      end
    end
  end

  disk_uri
end

def exec_command(cmd)
  Open3.popen2(cmd) do |stdin, out, wait_thr|
    out.each_line do |line|
      puts line
    end
    exit_status = wait_thr.value
    if exit_status != 0
      puts "error running command: #{cmd}"
      exit(1)
    end
  end
end

if find_executable('packer').nil?
  abort("ERROR: cannot find 'packer' on the path")
end

if find_executable('curl').nil?
  abort("ERROR: cannot find 'curl' on the path")
end

# find sha1sum executable name
SHA1SUM='sha1sum'
if find_executable(SHA1SUM) == nil
  SHA1SUM='shasum' # OS X
  if find_executable(SHA1SUM) == nil
    abort("ERROR: cannot find 'sha1sum' or 'sha1sum' on the path")
  end
end

FileUtils.mkdir_p(OUTPUT_DIR)
output_dir = File.absolute_path(OUTPUT_DIR)

BUILDER_PATH = File.expand_path("../..", __FILE__)
azure_config = File.join(BUILDER_PATH, "azure")

FileUtils.mv(AGENT_PATH, File.join(azure_config, "agent.zip"))
FileUtils.mv(AGENT_DEPS_PATH, File.join(azure_config, "agent-dependencies.zip"))

disk_uri = run_packer(File.join(azure_config, "packer.json"))
exec_command("curl -o '#{output_dir}/root.vhd' '#{disk_uri}'")

Dir.mktmpdir do |dir|
  exec_command("tar czvf #{dir}/image -C #{output_dir} root.vhd")
  IMAGE_SHA1=`#{SHA1SUM} #{dir}/image | cut -d ' ' -f 1 | xargs echo -n`

  MFTemplate.new("#{BUILDER_PATH}/erb_templates/azure/stemcell.MF.erb", VERSION, sha1: IMAGE_SHA1).save(dir)

  stemcell_filename = File.join(output_dir, "bosh-stemcell-#{VERSION}-azure-hyperv-windows-2012R2-go_agent.tgz")

  exec_command("tar czvf #{stemcell_filename} -C #{dir} stemcell.MF image")
end
