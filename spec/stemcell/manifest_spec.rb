require 'stemcell/manifest'

describe Stemcell::Manifest do
  describe 'Base' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        manifest = Stemcell::Manifest::Base.new('base', '1.0', 'sha', 'os').dump
        expect(YAML.load(manifest)).to eq(
          'name' => 'base',
          'version' => '1.0',
          'sha1' => 'sha',
          'operating_system' => 'os',
          'cloud_properties' => {}
        )
      end
    end
  end

  describe 'Aws' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        amis = [
          {
            'region' => 'region1',
            'ami_id' => 'ami1'
          },
          {
            'region' => 'region2',
            'ami_id' => 'ami2'
          }
        ]
        manifest = Stemcell::Manifest::Aws.new('1.0', 'some-os', amis).dump
        expect(YAML.load(manifest)).to eq(
          'name' => 'bosh-aws-xen-hvm-some-os-stemcell-go_agent',
          'version' => '1.0',
          'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
          'operating_system' => 'some-os',
          'cloud_properties' => {
            'infrastructure' => 'aws',
            'ami' => {
              'region1' => 'ami1',
              'region2' => 'ami2'
            }
          }
        )
      end
    end
  end

  describe 'Gcp' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        manifest = Stemcell::Manifest::Gcp.new('1.0', 'some-os',
                                               'https://google.com/stemcell').dump
        expect(YAML.load(manifest)).to eq(
          'name' => 'bosh-google-kvm-some-os-go_agent',
          'version' => '1.0',
          'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
          'operating_system' => 'some-os',
          'cloud_properties' => {
            'infrastructure' => 'google',
            'image_url' => 'https://google.com/stemcell'
          }
        )
      end
    end
  end

  describe 'VSphere' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        manifest = Stemcell::Manifest::VSphere.new('1.0', 'sha',
                                                   'some-os').dump
        expect(YAML.load(manifest)).to eq(
          'name' => 'bosh-vsphere-esxi-some-os-go_agent',
          'version' => '1.0',
          'sha1' => 'sha',
          'operating_system' => 'some-os',
          'cloud_properties' => {
            'infrastructure' => 'vsphere',
            'hypervisor' => 'esxi'
          }
        )
      end
    end
  end

  describe 'Azure' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        manifest = Stemcell::Manifest::Azure.new('1.0', 'some-os', 'some-publisher',
                                                 'some-offer', 'some-sku').dump
        expect(YAML.load(manifest)).to eq(
          'name' => 'bosh-azure-hyperv-some-os-go_agent',
          'version' => '1.0',
          'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
          'operating_system' => 'some-os',
          'cloud_properties' => {
            'infrastructure' => 'azure',
            'image' => {
              'offer' => 'some-offer',
              'publisher' => 'some-publisher',
              'sku' => 'some-sku',
              'version' => '1.0'
            }
          }
        )
      end
    end
  end

  describe 'OpenStack' do
    describe 'dump' do
      it 'returns a valid stemcell manifest yaml string' do
        pending('not yet implemented')
        fail
      end
    end
  end
end
