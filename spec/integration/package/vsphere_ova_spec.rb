require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/package/vsphere_ova.rake', __FILE__)

describe 'Package::vsphere_ova' do
  it 'should package ova file into a stemcell' do
    Dir.mktmpdir('bosh-windows-stemcell') do |tmpdir|
      FileUtils.cp(File.expand_path(File.join(Dir.pwd,"spec","fixtures","vsphere","image")), tmpdir)
      ova_file_name = File.expand_path(File.join(tmpdir,"image"))
      version = '1.0.0'
      agent_commit = 'abcd123'
      Rake::Task['package:vsphere_ova'].invoke(
        ova_file_name,tmpdir,
        version,agent_commit)
      pattern = File.join(tmpdir, "*.tgz").gsub('\\', '/')
      files = Dir.glob(pattern)
      expect(files.length).to eq(1)
      tarball = files[0]
      files_in_tgz = tgz_file_list(tarball)
      expect(files_in_tgz).to include(
        'apply_spec.yml'
      )
    end
  end

end
