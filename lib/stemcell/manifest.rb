require 'yaml'

module Stemcell
  module Manifest
    EMPTY_FILE_SHA = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'.freeze

    class Base
      def initialize(name, version, sha, os)
        @contents = {
          'name' => name,
          'version' => version,
          'sha1' => sha,
          'operating_system' => os,
          'cloud_properties' => {}
        }
      end

      def dump
        YAML.dump(@contents)
      end
    end

    class Aws < Base
      def initialize(version, os, amis)
        super("bosh-aws-xen-hvm-#{os}-stemcell-go_agent", version, EMPTY_FILE_SHA, os)
        cloud_properties = {
          'infrastructure' => 'aws',
          'ami' => {}
        }
        amis.each do |ami|
          cloud_properties['ami'][ami['region']] = ami['ami_id']
        end
        @contents['cloud_properties'] = cloud_properties
      end
    end

    class Gcp < Base
      def initialize(version, os, image_url)
        super("bosh-google-kvm-#{os}-go_agent", version, EMPTY_FILE_SHA, os)
        @contents['cloud_properties'] = {
          'infrastructure' => 'google',
          'image_url' => image_url
        }
      end
    end

    class VSphere < Base
      def initialize(version, sha, os)
        super("bosh-vsphere-esxi-#{os}-go_agent", version, sha, os)
        @contents['cloud_properties'] = {
          'infrastructure' => 'vsphere',
          'hypervisor' => 'esxi'
        }
      end
    end

    class Azure < Base
      def initialize(version, os, publisher, offer, sku)
        super("bosh-azure-hyperv-#{os}-go_agent", version, EMPTY_FILE_SHA, os)
        @contents['cloud_properties'] = {
          'infrastructure' => 'azure',
          'image' => {
            'offer' => offer,
            'publisher' => publisher,
            'sku' => sku,
            'version' => format_version(version)
          }
        }
      end

      def format_version(version)
        new_version = version.dup
        new_version.slice!("0-build.")
        return new_version
      end
    end

    class OpenStack < Base
    end
  end
end
