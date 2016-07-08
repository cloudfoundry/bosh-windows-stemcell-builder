#!/usr/bin/env ruby

require 'fileutils'
require 'zlib'
require 'erb'
require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'

CONFIG_PATH = 'packer-vsphere.json'

VERSION = File.read("version/number").chomp
DEPS_URL = File.read("bosh-agent-deps-zip/url").chomp
AGENT_URL = File.read("bosh-agent-zip/url").chomp
AGENT_COMMIT = File.read("bosh-agent-version/number").chomp

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
ISO_URL = ENV.fetch('ISO_URL')
ISO_CHECKSUM_TYPE = ENV.fetch('ISO_CHECKSUM_TYPE')
ISO_CHECKSUM = ENV.fetch('ISO_CHECKSUM')
MEMSIZE = ENV.fetch('MEMSIZE')
NUMVCPUS = ENV.fetch('NUMVCPUS')
REMOTE_HOST = ENV.fetch('REMOTE_HOST')
REMOTE_PORT = ENV.fetch('REMOTE_PORT')
REMOTE_DATASTORE = ENV.fetch('REMOTE_DATASTORE')
REMOTE_CACHE_DATASTORE = ENV.fetch('REMOTE_CACHE_DATASTORE')
REMOTE_CACHE_DIRECTORY = ENV.fetch('REMOTE_CACHE_DIRECTORY')
REMOTE_USERNAME = ENV.fetch('REMOTE_USERNAME')
REMOTE_PASSWORD = ENV.fetch('REMOTE_PASSWORD')
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
IMAGE_PATH = "#{OUTPUT_DIR}/image"


def gzip_file(name, output)
  Zlib::GzipWriter.open(output) do |gz|
   File.open(name) do |fp|
     while chunk = fp.read(32 * 1024) do
       gz.write chunk
     end
   end
   gz.close
  end
end

def packer_args(command)
  args = %{
    packer #{command} \
    -var "iso_url=#{ISO_URL}" \
    -var "iso_checksum_type=#{ISO_CHECKSUM_TYPE}" \
    -var "iso_checksum=#{ISO_CHECKSUM}" \
    -var "deps_url=#{DEPS_URL}" \
    -var "agent_url=#{AGENT_URL}" \
    -var "memsize=#{MEMSIZE}" \
    -var "numvcpus=#{NUMVCPUS}" \
    -var "remote_host=#{REMOTE_HOST}" \
    -var "remote_port=#{REMOTE_PORT}" \
    -var "remote_datastore=#{REMOTE_DATASTORE}" \
    -var "remote_cache_datastore=#{REMOTE_CACHE_DATASTORE}" \
    -var "remote_cache_directory=#{REMOTE_CACHE_DIRECTORY}" \
    -var "remote_username=#{REMOTE_USERNAME}" \
    -var "remote_password=#{REMOTE_PASSWORD}" \
    -var "administrator_password=#{ADMINISTRATOR_PASSWORD}" \
    #{CONFIG_PATH}
  }
  args
end

def packer_command(command)
  args = packer_args(command)
  Open3.popen3(args) do |stdin, stdout, stderr, wait_thr|
    stdout.each_line do |line|
      puts line
    end
    exit_status = wait_thr.value
    if exit_status != 0
      puts stderr.readlines
      puts "packer failed #{exit_status}"
      exit(1)
    end
  end
end

def exec_command(cmd)
  `#{cmd}`
  exit 1 unless $?.success?
end

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
  def initialize(template, version, sha1)
    super(template)
    @version = version
    @sha1 = sha1
  end
end

class ApplySpecTemplate < Template
  def initialize(template, agent_commit)
    super(template)
    @agent_commit = agent_commit
  end
end

FileUtils.mkdir_p(OUTPUT_DIR)
output_dir = File.absolute_path(OUTPUT_DIR)

Dir.chdir(File.dirname(__FILE__)) do
  packer_command('validate')
  packer_command('build')

  gzip_file('packer-vmware-iso/packer-vmware-iso.ova/packer-vmware-iso.ova', "#{IMAGE_PATH}")

  IMAGE_SHA1=`sha1sum #{IMAGE_PATH} | cut -d ' ' -f 1`

  Dir.mktmpdir do |dir|
    stemcell_dir = "templates/vsphere/stemcell"

    MFTemplate.new("#{stemcell_dir}/stemcell.MF.erb", VERSION, IMAGE_SHA1).save(dir)
    ApplySpecTemplate.new("#{stemcell_dir}/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
    FileUtils.cp("#{IMAGE_PATH}", dir)

    stemcell_filename = "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz"

    exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
  end
end
