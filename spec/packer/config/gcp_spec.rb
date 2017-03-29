require 'packer/config'

describe Packer::Config::Gcp do
  describe 'builders' do
    it 'returns the expected builders' do
      account_json = 'some-account-json'
      project_id = 'some-project-id'
      source_image = 'some-base-image'
      output_dir = 'some-output-directory'
      builders = Packer::Config::Gcp.new(
        account_json,
        project_id,
        source_image,
        output_dir
      ).builders
      expect(builders[0]).to include(
        'type' => 'googlecompute',
        'account_file' => account_json,
        'project_id' => project_id,
        'tags' => ['winrm'],
        'source_image' => source_image,
        'image_family' => 'windows-2012-r2',
        'zone' => 'us-east1-c',
        'disk_size' => 50,
        'machine_type' => 'n1-standard-4',
        'omit_external_ip' => false,
        'communicator' => 'winrm',
        'winrm_username' => 'winrmuser',
        'winrm_use_ssl' => false,
        'metadata' => {
          'sysprep-specialize-script-url' => 'https://raw.githubusercontent.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/master/scripts/setup-winrm.ps1'
        }
      )
      expect(builders[0]['image_name']).to match(/packer-\d+/)
    end
  end

  describe 'provisioners' do
    it 'returns the expected provisioners' do
      provisioners = Packer::Config::Gcp.new({}.to_json, '', {}.to_json, 'some-output-directory').provisioners
      expect(provisioners).to eq(
        [
          Packer::Config::Provisioners::INCREASE_WINRM_LIMITS,
          Packer::Config::Provisioners::CREATE_PROVISION_DIR,
          Packer::Config::Provisioners::UPLOAD_BOSH_PSMODULES,
          Packer::Config::Provisioners::INSTALL_BOSH_PSMODULES,
          Packer::Config::Provisioners::UPLOAD_AGENT,
          Packer::Config::Provisioners::INSTALL_CF_FEATURES,
          Packer::Config::Provisioners.install_agent("gcp"),
          Packer::Config::Provisioners.download_windows_updates('some-output-directory'),
          Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
          Packer::Config::Provisioners::DISABLE_SERVICES,
          Packer::Config::Provisioners::SET_FIREWALL,
          Packer::Config::Provisioners::CLEANUP_ARTIFACTS
        ].flatten
      )
    end
  end
end
