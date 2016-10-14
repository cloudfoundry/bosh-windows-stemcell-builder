#!/usr/bin/env ruby

require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'fileutils'
require 'mkmf'
require_relative '../erb_templates/templates.rb'

VERSION = File.read("version/number").chomp
DEPS_URL = File.read("bosh-agent-deps-zip/url").chomp
AGENT_URL = File.read("bosh-agent-zip/url").chomp

AGENT_COMMIT = File.read("bosh-agent-sha/sha").chomp

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
AWS_ACCESS_KEY = ENV.fetch("AWS_ACCESS_KEY")
AWS_SECRET_KEY = ENV.fetch("AWS_SECRET_KEY")
AMI_NAME = "BOSH-" + SecureRandom.uuid

VPC_ID_US_EAST_1 = ENV.fetch("VPC_ID_US_EAST_1")
SUBNET_ID_US_EAST_1 = ENV.fetch("SUBNET_ID_US_EAST_1")
BASE_AMI_ID_US_EAST_1 = File.read("windows-ami-us-east-1/version").chomp
VPC_ID_US_WEST_2 = ENV.fetch("VPC_ID_US_WEST_2")
SUBNET_ID_US_WEST_2 = ENV.fetch("SUBNET_ID_US_WEST_2")
BASE_AMI_ID_US_WEST_2 = File.read("windows-ami-us-west-2/version").chomp

def parse_ami(line)
  # The -machine-readable flag must be set for this to work
  # ex: packer build -machine-readable <args>
  unless line.include?(",artifact,0,id,")
    return
  end

  region_id = line.split(",").last.split(":")
  return {:region=> region_id[0].chomp, :ami_id=> region_id[1].chomp}
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
      -var "ami_name=#{AMI_NAME}" \
      \
      -var "base_ami_id_us_east_1=#{BASE_AMI_ID_US_EAST_1}" \
      -var "vpc_id_us_east_1=#{VPC_ID_US_EAST_1}" \
      -var "subnet_id_us_east_1=#{SUBNET_ID_US_EAST_1}" \
      \
      -var "base_ami_id_us_west_2=#{BASE_AMI_ID_US_WEST_2}" \
      -var "vpc_id_us_west_2=#{VPC_ID_US_WEST_2}" \
      -var "subnet_id_us_west_2=#{SUBNET_ID_US_WEST_2}" \
      #{config_path}
    }

    amis = []
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdout.each_line do |line|
        puts line
        ami = parse_ami(line)
        if !ami.nil?
          amis.push(ami)
        end
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts stderr.readlines
        puts "packer build failed #{exit_status}"
        exit(1)
      end
    end
    amis
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

amis = run_packer(packer_config)
if amis.nil? || amis.empty?
  abort("ERROR: could not parse AMI IDs")
end

Dir.mktmpdir do |dir|
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/aws/stemcell.MF.erb", VERSION, amis: amis).save(dir)
  ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  exec_command("touch #{dir}/image")

  stemcell_filename = "light-bosh-stemcell-#{VERSION}-aws-xen-hvm-windows2012R2-go_agent.tgz"

  exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
end
