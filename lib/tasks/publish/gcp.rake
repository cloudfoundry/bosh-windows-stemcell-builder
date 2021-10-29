require 'rspec/core/rake_task'
require 'rubygems/package'
require 'yaml'

require_relative '../../stemcell/publisher/gcp'
require_relative '../../stemcell/labeler/gcp'

def read_from_tgz(path, filename)
  contents = ''
  tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(path))
  tar_extract.rewind
  tar_extract.each do |entry|
    if entry.full_name.include?(filename)
      contents = entry.read
    end
  end
  tar_extract.close
  contents
end

def image_url
  root_dir = File.expand_path('../../../../../', __FILE__)
  pattern = File.join(root_dir, 'bosh-windows-stemcell', '*.tgz')
  stemcell = Dir.glob(pattern)[0]
  if stemcell.nil?
    abort "Unable to find stemcell: #{pattern}"
  end

  stemcell_mf = read_from_tgz(stemcell, 'stemcell.MF')
  manifest = YAML.load(stemcell_mf)
  manifest['cloud_properties']['image_url']
end

namespace :publish do
  desc 'Publish an image to GCP'
  task :gcp do
    account_json = ENV.fetch('ACCOUNT_JSON')
    vm_to_add = { image_url: image_url }

    Stemcell::Publisher::Gcp.publish(vm_to_add, account_json)
  end
end
