require 'packer/config'

describe Packer::Config::Gcp do
  describe 'builders' do
    it 'returns the expected builders' do
      account_json = 'some-account-json'
      project_id = 'some-project-id'
      source_image = 'some-base-image'
      image_family = 'some-image-family'
      output_dir = 'some-output-directory'
      builders = Packer::Config::Gcp.new(
        account_json,
        project_id,
        source_image,
        output_dir,
        image_family
      ).builders
      expect(builders[0]).to include(
        'type' => 'googlecompute',
        'account_file' => account_json,
        'project_id' => project_id,
        'tags' => ['winrm'],
        'source_image' => source_image,
        'image_family' => image_family,
        'zone' => 'us-east1-c',
        'disk_size' => 50,
        'machine_type' => 'n1-standard-4',
        'omit_external_ip' => false,
        'communicator' => 'winrm',
        'winrm_username' => 'winrmuser',
        'winrm_use_ssl' => false,
        'winrm_timeout' => '1h',
        'metadata' => {
          'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/gcp/setup-winrm.ps1'
        }
      )
      expect(builders[0]['image_name']).to match(/packer-\d+/)
    end
  end

  describe 'provisioners' do
    context 'for a windows2012R2 image' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json, 'some-output-directory','windows-2012-r2').provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::BOSH_PSMODULES,
            Packer::Config::Provisioners::NEW_PROVISIONER,
            Packer::Config::Provisioners::INSTALL_CF_FEATURES,
            Packer::Config::Provisioners::install_windows_updates,
            Packer::Config::Provisioners::PROTECT_CF_CELL,
            Packer::Config::Provisioners.install_agent("gcp"),
            Packer::Config::Provisioners.download_windows_updates('some-output-directory'),
            Packer::Config::Provisioners::OPTIMIZE_DISK,
            Packer::Config::Provisioners::COMPRESS_DISK,
            Packer::Config::Provisioners::CLEAR_PROVISIONER,
            Packer::Config::Provisioners::sysprep_shutdown('gcp')
          ].flatten
        )
      end
    end

    context 'for a windows2016 image' do
      it 'returns the expected provisioners' do
        allow(SecureRandom).to receive(:hex).and_return("some-password")
        provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json, 'some-output-directory','windows-2016-core').provisioners
        expect(provisioners).to eq(
          [
            Packer::Config::Provisioners::BOSH_PSMODULES,
            Packer::Config::Provisioners::NEW_PROVISIONER,
            Packer::Config::Provisioners::INSTALL_CONTAINERS_FEATURE,
            Packer::Config::Provisioners.install_agent("gcp")
          ].flatten
        )
      end
    end
  end
end
