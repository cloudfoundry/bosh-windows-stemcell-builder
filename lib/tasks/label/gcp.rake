require 'rspec/core/rake_task'

require_relative '../../stemcell/labeler/gcp'

namespace :gcp do
  namespace :label do
    desc 'Label an image as not published'
    task :for_test do
      account_json = ENV.fetch('ACCOUNT_JSON')

      Stemcell::Labeler::Gcp.label(image_url, account_json, "published", "false")
    end

    desc 'Label an image as published'
    task :for_production do
      account_json = ENV.fetch('ACCOUNT_JSON')

      Stemcell::Labeler::Gcp.label(image_url, account_json, "published", "true")
    end
  end
end
