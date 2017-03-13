require 'stemcell/packager'
require 'rubygems/package'

describe Stemcell::Packager do
  before(:each) do
    @image = Tempfile.new('')
    File.open(@image.path, 'w') { |f| f.write('image-contents') }

    @output_directory = Dir.mktmpdir
    @untar_dir = Dir.mktmpdir
  end

  after(:each) do
    # @image.close
    @image.unlink
    FileUtils.remove_entry_secure(@output_directory)
    FileUtils.remove_entry_secure(@untar_dir)
  end

  describe 'package_image' do
    context 'with tar' do
      it 'tars and gzips the image' do
        packaged_image = Stemcell::Packager.package_image(image_path: @image.path, archive: true, output_directory: @output_directory)

        expect(File.basename(packaged_image)).to eq('image')

        expect { tgz_extract(packaged_image, @untar_dir) }.not_to raise_error

        raw_files = Dir[File.join(@untar_dir, '*')]
        expect(raw_files.length).to eq(1)

        expect(File.read(File.join(@untar_dir, File.basename(@image.path)))).to eq('image-contents')
      end
    end
    context 'without tar' do
      it 'gzips the image' do
        packaged_image = Stemcell::Packager.package_image(image_path: @image.path, archive: false, output_directory: @output_directory)

        expect(File.basename(packaged_image)).to eq('image')

        Zlib::GzipReader.open(packaged_image) do |gz|
          expect(gz.read).to eq('image-contents')
        end
      end
    end

    context 'when provided an invalid image path' do
      it 'raises InvalidImagePathError' do
        expect {
          Stemcell::Packager.package_image(image_path: 'invalid_path', archive: false, output_directory: @output_directory)
        }.to raise_error(Stemcell::Packager::InvalidImagePathError)
      end
    end

    context 'when provided an invalid output directory' do
      it 'raises InvalidOutputDirError' do
        expect {
          Stemcell::Packager.package_image(image_path: @image.path, archive: false, output_directory: 'invalid-dir')
        }.to raise_error(Stemcell::Packager::InvalidOutputDirError)
      end
    end
  end

  describe 'package' do
    it 'creates a valid stemcell tarball and sha in the output directory' do
      expect {
        Stemcell::Packager.package(iaas:  'foo-iaas',
                                   os:  'bar-os',
                                   is_light:  false,
                                   version:  '9999.99',
                                   image_path:  @image.path,
                                   manifest:  'some-manifest',
                                   apply_spec:  'some-apply-spec',
                                   output_directory:  @output_directory)
      }.not_to raise_error

      output_files = Dir[File.join(@output_directory, '*')]
      expect(output_files.length).to eq(2)

      stemcell_tarball_file = 'bosh-stemcell-9999.99-foo-iaas-bar-os-go_agent.tgz'
      expect(File.basename(output_files[0])).to eq(stemcell_tarball_file)

      stemcell_tarball_sha_file = 'bosh-stemcell-9999.99-foo-iaas-bar-os-go_agent.tgz.sha'
      expect(File.basename(output_files[1])).to eq(stemcell_tarball_sha_file)
      expect(File.read(output_files[1])).to eq(Digest::SHA1.hexdigest(File.read(output_files[0])))

      expect { tgz_extract(output_files[0], @untar_dir) }.not_to raise_error

      stemcell_files = Dir[File.join(@untar_dir, '*')]
      expect(stemcell_files.length).to eq(3)

      expect(File.read(File.join(@untar_dir, 'stemcell.MF'))).to eq('some-manifest')
      expect(FileUtils.compare_file(@image.path,
                                    File.join(@untar_dir,
                                              'image'))).to be_truthy
      expect(File.read(File.join(@untar_dir, 'apply_spec.yml'))).to eq('some-apply-spec')
    end

    context 'when a light stemcell is specified' do
      it 'creates a stemcell tarball that starts with "light-"' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: true,
                                     version: '',
                                     image_path: @image.path,
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: @output_directory)
        }.not_to raise_error

        output_files = Dir[File.join(@output_directory, '*')]
        expect(output_files.length).to eq(2)

        expect(File.basename(output_files[0])).to start_with('light-')
      end

      it 'creates an empty image file' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: true,
                                     version: '',
                                     image_path: 'invalid_path',
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: @output_directory)
        }.not_to raise_error

        output_files = Dir[File.join(@output_directory, '*')]
        expect(output_files.length).to eq(2)

        expect { tgz_extract(output_files[0], @untar_dir) }.not_to raise_error

        stemcell_files = Dir[File.join(@untar_dir, '*')]
        expect(stemcell_files.length).to eq(3)

        expect(File.size(File.join(@untar_dir, 'image'))).to eq(0)
      end

      it 'writes a sha file' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: true,
                                     version: '',
                                     image_path: 'invalid_path',
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: @output_directory)
        }.not_to raise_error

        output_files = Dir[File.join(@output_directory, '*')]
        expect(output_files.length).to eq(2)

        expect(File.read(output_files[1])).to eq(Digest::SHA1.hexdigest(File.read(output_files[0])))
      end
    end

    context 'when provided an invalid image path' do
      it 'raises InvalidImagePathError' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: false,
                                     version: '',
                                     image_path: 'invalid_path',
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: @output_directory)
        }.to raise_error(Stemcell::Packager::InvalidImagePathError)
      end
    end

    context 'when provided an invalid output directory' do
      it 'raises InvalidOutputDirError' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: false,
                                     version: '',
                                     image_path: @image.path,
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: 'invalid_path')
        }.to raise_error(Stemcell::Packager::InvalidOutputDirError)
      end
    end
  end
end
