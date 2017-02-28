require 'downloader'
require 'tempfile'

describe Downloader do
  describe 'download' do
    it 'should download a file' do
      src = Tempfile.new('')
      src.write('some-contents')
      src.close

      dst = Tempfile.new('')
      dst.close

      Downloader.download(src.path, dst.path)
      expect(File.read(dst.path)).to eq('some-contents')
    end
  end
end
