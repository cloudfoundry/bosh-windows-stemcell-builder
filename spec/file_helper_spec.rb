require 'file_helper'

describe FileHelper do
  describe '.parse_vhd_version' do
    it 'parses the version from input windows 1709 vhd' do
      vhd_filename = 'some.file-Containers-170823-en-us'
      expect(FileHelper.parse_vhd_version(vhd_filename)).to eq('170823')
    end

    it 'parses the version from input windows 2012R2 vhd' do
      vhd_filename = 'some.file.patched-170802-110000'
      expect(FileHelper.parse_vhd_version(vhd_filename)).to eq('170802-110000')
    end
  end
end
