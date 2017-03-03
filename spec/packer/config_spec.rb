require 'packer/config'

describe 'Config' do
  describe Packer::Config::Base do
  end

  describe Packer::Config::Aws do
    it 'foo' do
      Packer::Config::Aws.new.provisioners
    end
  end

  describe Packer::Config::Gcp do

  end

  describe Packer::Config::VSphere do

  end

  describe Packer::Config::Azure do

  end

  describe Packer::Config::OpenStack do

  end
end
