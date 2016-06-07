#!/usr/bin/env ruby

require 'erb'
require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'fileutils'

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

class Template
  include ERB::Util

  def initialize(filename)
    @filename = filename
    @template = File.read(filename)
  end

  def render
    ERB.new(@template).result(binding)
  end

  def save(dir)
    path = File.join(dir, File.basename(@filename, ".erb"))
    File.open(path, "w+") do |f|
      puts "#{path}\n#{render}"
      f.write(render)
    end
  end
end

class MFTemplate < Template
  def initialize(template, version, ami_id)
    super(template)
    @version = version
    @ami_id = ami_id
  end
end

class ApplySpecTemplate < Template
  def initialize(template, agent_commit)
    super(template)
    @agent_commit = agent_commit
  end
end

def parse_ami_id(line)
  unless line.include?("amazon-ebs,artifact,0,id,")
    return
  end
  return line.split(",").last.split(":").last
end

def run_packer(packer_path)
  config_path = "packer.json"
  command = %{
    #{packer_path} build \
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
      if ami_id == nil
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

def exec_command(cmd)
  `#{cmd}`
  exit 1 unless $?.success?
end

PACKER_URL="https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip"
def provision
  dirname = Dir.tmpdir
  exec_command("apt-get update && apt-get -y install zip unzip")
  exec_command("wget #{PACKER_URL} -O #{dirname}/packer.zip")
  exec_command("unzip #{dirname}/packer.zip -d #{dirname}/")
  "#{dirname}/packer"
end

FileUtils.mkdir_p(OUTPUT_DIR)
output_dir = File.absolute_path(OUTPUT_DIR)

Dir.chdir(File.dirname(__FILE__)) do
  packer_bin = provision
  ami_id = run_packer(packer_bin)

  Dir.mktmpdir do |dir|
    stemcell_dir = "templates/stemcell"

    MFTemplate.new("#{stemcell_dir}/stemcell.MF.erb", VERSION, ami_id).save(dir)
    ApplySpecTemplate.new("#{stemcell_dir}/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
    FileUtils.cp("#{stemcell_dir}/image", dir)

    stemcell_filename = "light-bosh-stemcell-#{VERSION}-aws-xen-hvm-windows2012R2-go_agent.tgz"

    exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
  end
end
