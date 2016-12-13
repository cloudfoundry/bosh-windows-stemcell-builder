#!/usr/bin/env ruby

require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'fileutils'
require 'mkmf'
require 'json'
require 'yaml'
require 'tempfile'
require_relative '../erb_templates/templates.rb'

VERSION = File.read("version/number").chomp
ROOT_DIR = File.expand_path(File.join(File.dirname(File.expand_path(__FILE__)), '..', '..'))
BOSH_AGENT_DEPS_PATH = File.join(ROOT_DIR, "bosh-agent-deps-zip", "agent-dependencies.zip")
AGENT_URL = File.read("bosh-agent-zip/url").chomp
AGENT_COMMIT = File.read("bosh-agent-sha/sha").chomp

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
ACCOUNT_JSON = ENV.fetch('ACCOUNT_JSON')
PROJECT_ID = JSON.parse(ACCOUNT_JSON)['project_id']
OS_VERSION = ENV.fetch("OS_VERSION")

def run_packer(config_path)
  Dir.chdir(File.dirname(config_path)) do
    command = %{
      packer build \
      -machine-readable \
      #{config_path}
    }

    image = nil
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdout.each_line do |line|
        puts line
        if line.include?(",artifact,0,id,")
          image = line.split(",").last.chomp
        end
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts stderr.readlines
        puts "packer build failed #{exit_status}"
        exit(1)
      end
    end
    image
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
output_dir = File.absolute_path(OUTPUT_DIR)

BUILDER_PATH = File.expand_path("../..", __FILE__)
account_json = Tempfile.new(['account','.json']).tap(&:close).path
File.write(account_json, ACCOUNT_JSON)
gcp_config = File.join(BUILDER_PATH, "gcp")

GCPPackerJsonTemplate.new("#{BUILDER_PATH}/erb_templates/gcp/packer.json.erb",
                          account_json, PROJECT_ID, AGENT_URL, BOSH_AGENT_DEPS_PATH).save(gcp_config)

image_name = run_packer(File.join(gcp_config, "packer.json"))
if image_name.nil? || image_name.empty?
  abort("ERROR: could not parse GCP Image Name")
end
image_self_link = "https://www.googleapis.com/compute/v1/projects/#{PROJECT_ID}/global/images/#{image_name}"

Dir.mktmpdir do |dir|
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/gcp/stemcell.MF.erb", VERSION, image_self_link: image_self_link, os_version: OS_VERSION).save(dir)
  ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  exec_command("touch #{dir}/image")

  stemcell_filename = "light-bosh-stemcell-#{VERSION}-google-kvm-windows-2012-r2-go_agent.tgz"

  exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
end
