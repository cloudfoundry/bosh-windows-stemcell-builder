#!/usr/bin/env ruby

require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'fileutils'
require 'mkmf'
require_relative '../erb_templates/templates.rb'

BASE_AMI_ID = File.read("windows-ami/version").chomp
VERSION = File.read("version/number").chomp
DEPS_URL = File.read("bosh-agent-deps-zip/url").chomp
AGENT_URL = File.read("bosh-agent-zip/url").chomp

AGENT_COMMIT = `git --git-dir bosh-agent/.git rev-parse HEAD`.chomp

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
AWS_ACCESS_KEY = ENV.fetch("AWS_ACCESS_KEY")
AWS_SECRET_KEY = ENV.fetch("AWS_SECRET_KEY")
VPC_ID = ENV.fetch("VPC_ID")
SUBNET_ID = ENV.fetch("SUBNET_ID")
AMI_NAME = "BOSH-" + SecureRandom.uuid

def parse_ami_id(line)
  # The -machine-readable flag must be set for this to work
  # ex: packer build -machine-readable <args>
  unless line.include?("amazon-ebs,artifact,0,id,")
    return
  end
  return line.split(",").last.split(":").last
end

def run_packer(config_path)
  Dir.chdir(File.dirname(config_path)) do
    command = %{
      packer build \
      -machine-readable \
      -var "aws_access_key=#{AWS_ACCESS_KEY}" \
      -var "aws_secret_key=#{AWS_SECRET_KEY}" \
      -var "deps_url=#{DEPS_URL}" \
      -var "agent_url=#{AGENT_URL}" \
      -var "base_ami_id=#{BASE_AMI_ID}" \
      -var "vpc_id=#{VPC_ID}" \
      -var "subnet_id=#{SUBNET_ID}" \
      -var "ami_name=#{AMI_NAME}" \
      #{config_path}
    }

    ami_id = nil
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdout.each_line do |line|
        puts line
        if ami_id.nil?
          ami_id = parse_ami_id(line)
        end
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts stderr.readlines
        puts "packer build failed #{exit_status}"
        exit(1)
      end
    end
    ami_id
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
packer_config = File.join(BUILDER_PATH, "aws","packer.json")

ami_id = run_packer(packer_config)
if ami_id.nil? || ami_id.empty?
  abort("ERROR: could not parse AMI ID")
end

Dir.mktmpdir do |dir|
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/aws/stemcell.MF.erb", VERSION, ami_id: ami_id).save(dir)
  ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  exec_command("touch #{dir}/image")

  stemcell_filename = "light-bosh-stemcell-#{VERSION}-aws-xen-hvm-windows2012R2-go_agent.tgz"

  exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
end
