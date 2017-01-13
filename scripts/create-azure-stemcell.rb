#!/usr/bin/env ruby

require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'fileutils'
require 'mkmf'
require 'json'
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

def run_packer(config_path)
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
      #{config_path}
    }

    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value
      if exit_status != 0
        puts stderr.readlines
        puts "packer build failed #{exit_status}"
        exit(1)
      end
    end
  end
end

def exec_command(cmd)
  `#{cmd}`
  exit 1 unless $?.success?
end

if find_executable('packer').nil?
  abort("ERROR: cannot find 'packer' on the path")
end

FileUtils.mkdir_p(OUTPUT_DIR)
# output_dir = File.absolute_path(OUTPUT_DIR)

BUILDER_PATH = File.expand_path("../..", __FILE__)
azure_config = File.join(BUILDER_PATH, "azure")

FileUtils.mv(AGENT_PATH, File.join(azure_config, "agent.zip"))
FileUtils.mv(AGENT_DEPS_PATH, File.join(azure_config, "agent-dependencies.zip"))

run_packer(File.join(azure_config, "packer.json"))

Dir.mktmpdir do |dir|
  # WIP DO AZURE STEMCELL
  # MFTemplate.new("#{BUILDER_PATH}/erb_templates/aws/stemcell.MF.erb", VERSION, amis: amis, os_version: OS_VERSION).save(dir)
  # ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  # exec_command("touch #{dir}/image")

  # stemcell_filename = "light-bosh-stemcell-#{VERSION}-aws-xen-hvm-windows2012R2-go_agent.tgz"

  # exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
end
