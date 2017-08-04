require 'file_helper'

describe FileHelper do
  describe '.parse_vhd_version' do
    it 'parses the version from input vhd' do
      vhd_filename = 'some.file.patched-170802-110000'
      expect(FileHelper.parse_vhd_version(vhd_filename)).to eq('170802-110000')
    end
  end
end
