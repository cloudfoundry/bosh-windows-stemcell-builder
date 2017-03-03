#!/usr/bin/env ruby

require 'open3'
require 'tmpdir'
require 'scanf.rb'
require 'fileutils'
require_relative './s3-client.rb'
require 'mkmf'


# Concourse inputs
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH = File.expand_path("../..", __FILE__)
OUTPUT_DIR = File.join(BUILDER_PATH, "vmx-output")

raw_version = File.read("vmx-version/number").chomp
INPUT_VMX_VERSION = raw_version.scan(/(\d+)\./).flatten.first

VMX_BUCKET = ENV.fetch("INPUT_BUCKET")
VMX_CACHE = ENV.fetch("VMX_CACHE")

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

def packer_command(command, config_path, vars)
  Dir.chdir(File.dirname(config_path)) do

    args = %{
      packer #{command} \
      -var "source_path=#{vars['source_path']}" \
      -var "administrator_password=#{vars['administrator_password']}" \
      -var "output_directory=#{vars['output_directory']}" \
      #{config_path}
    }

    Open3.popen2e(args) do |stdin, stdout_stderr, wait_thr|
      stdout_stderr.each_line do |line|
        puts line
      end
      exit_status = wait_thr.value
      if exit_status != 0
        raise "packer failed #{exit_status}"
      end
    end
  end
end

def find_vmx_file(dir)
  pattern = File.join(dir, "*.vmx").gsub('\\', '/')
  files = Dir.glob(pattern)
  if files.length == 0
    raise "No vmx files in directory: #{dir}"
  end
  if files.length > 1
    raise "Too many vmx files in directory: #{files}"
  end
  return files[0]
end

if find_executable('packer') == nil
  abort("ERROR: cannot find 'packer' on the path")
end
if find_executable('tar.exe') == nil
  abort("ERROR: cannot find 'tar' on the path")
end

# Find the vmx tarball matching version, download if not cached
FileUtils.mkdir_p(VMX_CACHE)
vmx_tarball = File.join(VMX_CACHE,"vmx-v#{INPUT_VMX_VERSION}.tgz")
puts "Checking for #{vmx_tarball}"
if !File.exist?(vmx_tarball)
  S3Client.new().Get(VMX_BUCKET,"vmx-v#{INPUT_VMX_VERSION}.tgz",vmx_tarball)
else
  puts "VMX file #{vmx_tarball} found in cache."
end

# Find the vmx directory matching version, untar if not cached
VMX_DIR=File.join(VMX_CACHE,INPUT_VMX_VERSION)
puts "Checking for #{VMX_DIR}"
if !Dir.exist?(VMX_DIR)
  FileUtils.mkdir_p(VMX_DIR)
  exec_command("tar.exe -xzvf #{vmx_tarball} -C #{VMX_DIR}")
else
  puts "VMX dir #{VMX_DIR} found in cache."
end

latest_vmx = find_vmx_file(VMX_DIR)
puts "latest vmx file: #{latest_vmx}"

new_dirname = File.join(VMX_CACHE, "#{INPUT_VMX_VERSION.to_i+1}")
puts "new vmx directory: #{new_dirname}"

puts "output directory: #{OUTPUT_DIR}"

begin
  update_vars = {
    'source_path' => latest_vmx,
    'output_directory' => OUTPUT_DIR,
    'administrator_password' => ADMINISTRATOR_PASSWORD
  }

  puts "Starting Packer"
  packer_config = File.join(BUILDER_PATH, "vmx", "updates.json")
  packer_command('build', packer_config, update_vars)

  puts "tarballing VMX dir #{OUTPUT_DIR}..."
  new_vmx_tarball = "vmx-v#{INPUT_VMX_VERSION.to_i+1}.tgz"
  exec_command("tar czvf #{new_vmx_tarball} -C #{OUTPUT_DIR} *")
  S3Client.new().Put(VMX_BUCKET, File.basename(new_vmx_tarball), new_vmx_tarball)

  cached_tarball = File.join(VMX_CACHE, new_vmx_tarball)
  puts "moving VMX tarball #{new_vmx_tarball} to #{cached_tarball}"
  FileUtils.mv("#{new_vmx_tarball}", "#{cached_tarball}")
  puts "moving dir (#{OUTPUT_DIR}) to (#{new_dirname})"
  FileUtils.mv(OUTPUT_DIR, new_dirname)
end
