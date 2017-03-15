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
                                         regions).builders
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
      provisioners = Packer::Config::Aws.new('', '', []).provisioners
      expect(provisioners).to eq(
        [
          Packer::Config::Provisioners::CREATE_PROVISION_DIR,
          Packer::Config::Provisioners::UPLOAD_BOSH_PSMODULES,
          Packer::Config::Provisioners::INSTALL_BOSH_PSMODULES,
          Packer::Config::Provisioners::UPLOAD_AGENT,
          Packer::Config::Provisioners::INSTALL_CF_FEATURES,
          Packer::Config::Provisioners.install_agent("aws"),
          Packer::Config::Provisioners::CLEANUP_WINDOWS_FEATURES,
          Packer::Config::Provisioners::SET_EC2_PASSWORD,
          Packer::Config::Provisioners::DISABLE_SERVICES,
          Packer::Config::Provisioners::SET_FIREWALL,
          Packer::Config::Provisioners::DISABLE_WINRM_STARTUP,
          Packer::Config::Provisioners::CLEANUP_ARTIFACTS
        ]
      )
    end
  end

  describe 'dump' do
    it 'outputs a valid packer json config' do
      pending('packer validate actually requires files to exist')
      fail

      regions = [
        {
          'name' => 'us-east-1',
          'ami_name' => 'ami1',
          'base_ami' => 'baseami1',
          'vpc_id' => 'vpc1',
          'subnet_id' => 'subnet1',
          'security_group' => 'sg1'
        }
      ]
      config = Packer::Config::Aws.new('accesskey',
                                       'secretkey',
                                       regions).dump
      puts config
      runner = Packer::Runner.new(config)
      success = runner.run('validate', {})
      expect(success).to be(true)
    end
  end
end
