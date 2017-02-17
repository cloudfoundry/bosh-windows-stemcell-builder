require 'yaml'

module Stemcell
  module Manifest
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
        super('bosh-aws-xen-hvm-windows-stemcell-go_agent',
              version,
              'da39a3ee5e6b4b0d3255bfef95601890afd80709',
              os)
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
        super('bosh-google-kvm-windows2012R2-go_agent',
              version,
              'da39a3ee5e6b4b0d3255bfef95601890afd80709',
              os)
        @contents['cloud_properties'] = {
          'infrastructure' => 'google',
          'image_url' => image_url
        }
      end
    end

    class VSphere < Base
      def initialize(version, sha, os)
        super('bosh-vsphere-esxi-windows-2012R2-go_agent',
              version, sha, os)
        @contents['cloud_properties'] = {
          'infrastructure' => 'vsphere',
          'hypervisor' => 'esxi'
        }
      end
    end

    class Azure < Base
    end

    class OpenStack < Base
    end
  end
end
