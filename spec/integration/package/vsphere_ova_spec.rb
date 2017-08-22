require 'fileutils'
require 'json'
require 'rake'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'

load File.expand_path('../../../../lib/tasks/package/vsphere_ova.rake', __FILE__)

describe 'Package::vsphere_ova' do
  around(:each) do |example|
    Dir.mktmpdir('bosh-windows-stemcell') do |tmpdir|
      FileUtils.cp(File.expand_path(File.join(Dir.pwd,"spec","fixtures","vsphere","image")), tmpdir)
      @ova_file_name = File.expand_path(File.join(tmpdir,"image"))
      @version = '1.0.0'
      @agent_commit = `git --work-tree=src/github.com/cloudfoundry/bosh-agent/ rev-parse HEAD`.strip
      @output_directory = tmpdir
      example.run
    end
    Rake::Task['package:vsphere_ova'].reenable
  end

  it 'should package ova file into a stemcell' do
    updates_path = File.join(@output_directory, 'updates.txt')
    File.write(updates_path, 'some-updates')
    Rake::Task['package:vsphere_ova'].invoke(
      @ova_file_name,
      @output_directory,
      @version,
      updates_path
    )

    pattern = File.join(@output_directory, "bosh-stemcell-#{@version}-vsphere-esxi-windows2012R2-go_agent.tgz").gsub('\\', '/')
    files = Dir.glob(pattern)
    expect(files.length).to eq(1)

    tarball = files[0]
    files_in_tgz = tgz_file_list(tarball)
    expect(files_in_tgz).to contain_exactly(
      'stemcell.MF',
      'image',
      'apply_spec.yml',
      'updates.txt'
    )

    expect(read_from_tgz(tarball, 'apply_spec.yml')).to include @agent_commit
    expect(read_from_tgz(tarball, 'updates.txt')).to include 'some-updates'
    vsphere_metadata = <<END
cloud_properties:
  infrastructure: vsphere
  hypervisor: esxi
END
    expect(read_from_tgz(tarball, 'stemcell.MF')).to include(
      vsphere_metadata,
      "version: '1.0'\n")
  end
  context 'when updates path is not provided' do
    it 'should package ova file without updates list' do
      Rake::Task['package:vsphere_ova'].invoke(
        @ova_file_name,
        @output_directory,
        @version
      )

      pattern = File.join(@output_directory, "bosh-stemcell-#{@version}-vsphere-esxi-windows2012R2-go_agent.tgz").gsub('\\', '/')
      files = Dir.glob(pattern)
      expect(files.length).to eq(1)

      tarball = files[0]
      files_in_tgz = tgz_file_list(tarball)
      expect(files_in_tgz).to contain_exactly(
        'stemcell.MF',
        'image',
        'apply_spec.yml'
      )
    end
  end
end
