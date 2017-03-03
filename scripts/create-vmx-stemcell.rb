#!/usr/bin/env ruby

require 'open3'
require 'tmpdir'
require 'scanf.rb'
require 'fileutils'
require_relative './s3-client.rb'
require 'mkmf'
require 'digest'
require 'zlib'
require 'nokogiri'
require_relative '../erb_templates/templates.rb'


# Concourse inputs
ADMINISTRATOR_PASSWORD = ENV.fetch('ADMINISTRATOR_PASSWORD')
BUILDER_PATH = File.expand_path("../..", __FILE__)
OUTPUT_DIR = File.absolute_path("bosh-windows-stemcell")

raw_version = File.read("vmx-version/number").chomp
INPUT_VMX_VERSION = raw_version.scan(/(\d+)\./).flatten.first

VMX_BUCKET = ENV.fetch("INPUT_BUCKET")
VMX_CACHE = ENV.fetch("VMX_CACHE")
VERSION = File.read("version/number").chomp
OUTPUT_BUCKET = ENV.fetch("OUTPUT_BUCKET")

PRODUCT_KEY = ENV.fetch('PRODUCT_KEY')
OWNER = ENV.fetch('OWNER')
ORGANIZATION = ENV.fetch('ORGANIZATION')

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
      -var "product_key=#{PRODUCT_KEY}" \
      -var "owner=#{OWNER}" \
      -var "organization=#{ORGANIZATION}" \
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
if find_executable('ovftool') == nil
  abort("ERROR: cannot find 'ovftool' on the path")
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

FileUtils.rm_rf(OUTPUT_DIR) # packer will fail if the output directory exists already
output_dir = OUTPUT_DIR
stemcell_filename = File.join(output_dir, "bosh-stemcell-#{VERSION}-vsphere-esxi-windows2012R2-go_agent.tgz")
puts "output directory: #{OUTPUT_DIR}"

begin
  stemcell_vars = {
    'source_path' => latest_vmx,
    'output_directory' => output_dir,
    'administrator_password' => ADMINISTRATOR_PASSWORD
  }

  puts "Starting Packer"
  packer_config = File.join(BUILDER_PATH, "vmx", "stemcell.json")
  packer_command('build', packer_config, stemcell_vars)

  stemcell_vmx = find_vmx_file(output_dir)
  puts "new stemcell_vmx: #{stemcell_vmx}"

  ova_file = File.join(output_dir, 'image.ova')
  puts "Running ovftool"
  exec_command("ovftool #{stemcell_vmx} #{ova_file}")

  ova_file_path = File.absolute_path(ova_file)
  puts "OVA file path: #{ova_file_path}"

  Dir.mktmpdir do |dir|
    exec_command("tar xf #{ova_file_path} -C #{dir}")
    puts "#{dir} with ova file"
    file = File.open(File.join(dir,"image.ovf"))
    f = Nokogiri::XML(file)
    f.css("VirtualHardwareSection Item").select {|x| x.to_s =~ /ethernet/}.first.remove
    puts "Writing OVF file "
    File.write(File.join(dir,"image.ovf"), f.to_s)
    file.close
    puts "Wrote OVF file"
    Dir.chdir(dir) do
      exec_command("tar cf #{ova_file_path} *")
    end
    puts "Removed ethernet"
  end

  image_file = File.join(output_dir, 'image')
  puts "image_file: #{image_file}"

  puts "Gzip OVA file"
  gzip_file(ova_file, image_file)
  puts "Gziped"
  image_sha1 = Digest::SHA1.file(image_file).hexdigest
  MFTemplate.new("#{BUILDER_PATH}/erb_templates/vsphere/stemcell.MF.erb", VERSION, sha1: image_sha1).save(output_dir)



  exec_command("tar czvf #{stemcell_filename} -C #{output_dir} stemcell.MF image")
  S3Client.new().Put(OUTPUT_BUCKET, File.basename(stemcell_filename), stemcell_filename)
end
