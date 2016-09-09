#!/usr/bin/env ruby

require 'fileutils'
require 'zlib'
require 'tmpdir'
require 'open3'
require 'securerandom'
require 'pathname'
require 'mkmf'
require_relative '../erb_templates/templates.rb'

# concourse inputs
VERSION = File.read("version/number").chomp
DEPS_URL = File.read("bosh-agent-deps-zip/url").chomp
AGENT_URL = File.read("bosh-agent-zip/url").chomp
AGENT_COMMIT = File.read("bosh-agent-sha/sha").chomp

WINDOWS_UPDATE_PATH = File.absolute_path(Dir.glob('ps-windows-update/*.zip').first)
ISO_URL = File.absolute_path(Dir.glob('base-iso/*.iso').first)

OUTPUT_DIR = ENV.fetch("OUTPUT_DIR")
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

# erb_templates/network-interface-settings.xml
GUEST_NETWORK_ADDRESS = ENV.fetch('GUEST_NETWORK_ADDRESS')
GUEST_NETWORK_MASK = ENV.fetch('GUEST_NETWORK_MASK')
GUEST_NETWORK_GATEWAY = ENV.fetch('GUEST_NETWORK_GATEWAY')

def create_network_interface_settings(builder_path, address, mask, gateway)
  templatePath = "#{builder_path}/erb_templates/vsphere/network-interface-settings.xml.erb"
  settingsPath = "#{builder_path}/vsphere"

  # Manual network configuration (all specified)
  if (!address.nil? && !address.empty?) && (!mask.nil? && !mask.empty?) &&
     (!gateway.nil? && !gateway.empty?)
    NetworkInterfaceSettingsTemplate.new(templatePath, address, mask, gateway).save(settingsPath)

  # Ignore network settings (all nil)
  elsif (address.nil? || address.empty?) && (mask.nil? || mask.empty?) &&
        (gateway.nil? || gateway.empty?)
    File.write("#{settingsPath}/network-interface-settings.xml", 'IGNORE')

  # Error
  else
    abort("ERROR: invalid GUEST_NETWORK settings, all settings must be either " \
          "be specified or 'nil'.")
  end
end

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

def packer_command(command, config_path)
  Dir.chdir(File.dirname(config_path)) do

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
      -var "winrm_host=#{GUEST_NETWORK_ADDRESS}" \
      #{config_path}
    }
    Open3.popen2e(args) do |stdin, stdout_stderr, wait_thr|
      stdout_stderr.each_line do |line|
        puts line
      end
      exit_status = wait_thr.value
      if exit_status != 0
        puts "packer failed #{exit_status}"
        exit(1)
      end
    end
  end
end

def exec_command(cmd)
  `#{cmd}`
  exit 1 unless $?.success?
end

def install_ovftool
  files = Dir.glob("**/VMware-ovftool-*.bundle")
  if files == []
    abort("ERROR: cannot find 'ovftool' bundle")
  end
  ovftoolBundle = files[0]
  File.chmod(0777, ovftoolBundle)
  exec_command("#{ovftoolBundle} --required --eulas-agreed")
end

install_ovftool

if find_executable('ovftool') == nil
  abort("ERROR: cannot find 'ovftool' on the path")
end

if find_executable('packer') == nil
  abort("ERROR: cannot find 'packer' on the path")
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

IMAGE_PATH = "#{output_dir}/image"

BUILDER_PATH=File.expand_path("../..", __FILE__)

create_network_interface_settings(BUILDER_PATH, GUEST_NETWORK_ADDRESS, GUEST_NETWORK_MASK, GUEST_NETWORK_GATEWAY)

packer_config = File.join(BUILDER_PATH, "vsphere", "packer.json")
packer_command('validate', packer_config)

FileUtils.mv(WINDOWS_UPDATE_PATH, File.join(File.dirname(packer_config), "PSWindowsUpdate.zip"))

packer_command('build', packer_config)

ova_file = Dir.glob('**/packer-vmware-iso.ova' ).select { |fn| File.file?(fn) }
if ova_file.length == 0
  abort("ERROR: unable to find packer-vmware-iso.ova")
end
gzip_file(ova_file[0], "#{IMAGE_PATH}")

IMAGE_SHA1=`#{SHA1SUM} #{IMAGE_PATH} | cut -d ' ' -f 1 | xargs echo -n`

Dir.mktmpdir do |dir|
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/vsphere/stemcell.MF.erb", VERSION, sha1: IMAGE_SHA1).save(dir)
  ApplySpecTemplate.new("#{BUILDER_PATH}/erb_templates/apply_spec.yml.erb", AGENT_COMMIT).save(dir)
  FileUtils.cp("#{IMAGE_PATH}", dir)

  stemcell_filename = "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz"

  exec_command("tar czvf #{File.join(output_dir, stemcell_filename)} -C #{dir} stemcell.MF apply_spec.yml image")
end
