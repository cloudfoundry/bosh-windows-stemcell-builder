require 'packer/config'

describe Packer::Config::Aws do
  describe 'builders' do
    it 'returns the expected builders' do
      regions = [
        {
          'name' => 'region1',
          'ami_name' => 'ami1',
          'base_ami' => 'baseami1',
          'vpc_id' => 'vpc1',
          'subnet_id' => 'subnet1',
          'security_group' => 'sg1'
        }
      ]
      builders = Packer::Config::Aws.new('accesskey',
                                         'secretkey',
                                         regions,
                                         'some-output-directory').builders
      expect(builders[0]).to include(
        'name' => 'amazon-ebs-region1',
        'type' => 'amazon-ebs',
        'access_key' => 'accesskey',
        'secret_key' => 'secretkey',
        'region' => 'region1',
        'source_ami' => 'baseami1',
        'instance_type' => 'm4.xlarge',
        'vpc_id' => 'vpc1',
        'subnet_id' => 'subnet1',
        'associate_public_ip_address' => true,
        'communicator' => 'winrm',
        'winrm_username' => 'Administrator',
        'user_data_file' => 'scripts/aws/setup_winrm.txt',
        'security_group_id' => 'sg1',
        'ami_groups' => 'all'
      )
      expect(builders[0]['ami_name']).to match(/BOSH-.*-region1/)
    end
  end

  describe 'provisioners' do
    it 'returns the expected provisioners' do
      provisioners = Packer::Config::Aws.new('', '', [], 'some-output-directory').provisioners
      expect(provisioners).to eq(
        [
          Packer::Config::Provisioners::BOSH_PSMODULES,
          Packer::Config::Provisioners::NEW_PROVISIONER,
          Packer::Config::Provisioners::INSTALL_CF_FEATURES,
          Packer::Config::Provisioners::PROTECT_CF_CELL,
          Packer::Config::Provisioners.install_agent('aws'),
          Packer::Config::Provisioners.download_windows_updates('some-output-directory'),
          Packer::Config::Provisioners::OPTIMIZE_DISK,
          Packer::Config::Provisioners::COMPRESS_DISK,
          Packer::Config::Provisioners::CLEAR_PROVISIONER,
          Packer::Config::Provisioners::sysprep_shutdown('aws')
        ].flatten
      )
    end
  end
end
