require 'open-uri'

class Downloader
  def self.download(src, dst)
    IO.copy_stream(open(src), dst)
  end
end
