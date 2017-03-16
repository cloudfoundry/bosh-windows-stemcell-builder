require 'rspec/core/rake_task'
require 'json'

require_relative '../../zip_file'

namespace :package do
  desc 'Package VSphere OVA files into Stemcells'
  task :vsphere_ova, [:ova_file_name, :output_directory, :version, :agent_commit] do |t, args|
    ova_file_name = args[:ova_file_name]
    output_directory = args[:output_directory]
    version = args[:version]
    agent_commit = args[:agent_commit]
    os = 'windows2012R2'
    iaas = 'vsphere-esxi'

    image_path = File.join(output_directory, 'image')

    Stemcell::Packager.removeNIC(ova_file_name)
    Stemcell::Packager.gzip_file(ova_file_name, image_path)
    sha1_sum = Digest::SHA1.file(image_path).hexdigest

    manifest = Stemcell::Manifest::VSphere.new(version, sha1_sum, os).dump
    apply_spec = Stemcell::ApplySpec.new(agent_commit).dump

    Stemcell::Packager.package(
      iaas: iaas,
      os: os,
      is_light: false,
      version: version,
      image_path: image_path,
      manifest: manifest,
      apply_spec: apply_spec,
      output_directory: output_directory
    )
  end
end
