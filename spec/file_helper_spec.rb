require 'file_helper'

describe FileHelper do
  describe '.parse_vhd_version' do
    it 'parses the version from input vhd' do
      vhd_filename = 'some.file-Containers-170823-en-us'
      expect(FileHelper.parse_vhd_version(vhd_filename)).to eq('170823')
    end
  end
end
