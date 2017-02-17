require 'stemcell/packager'
require 'rubygems/package'

describe Stemcell::Packager do
  describe 'package' do
    before(:each) do
      @image = Tempfile.new('')
      File.open(@image.path, 'w') { |f| f.write('image') }

      @manifest = Tempfile.new('')
      File.open(@manifest.path, 'w') { |f| f.write('manifest') }

      @apply_spec = Tempfile.new('')
      File.open(@apply_spec.path, 'w') { |f| f.write('apply_spec') }

      @output_dir = Dir.mktmpdir
      @untar_dir = Dir.mktmpdir
    end

    after(:each) do
      # @image.close
      @image.unlink
      # @manifest.close
      @manifest.unlink
      # @apply_spec.close
      @apply_spec.unlink
      FileUtils.remove_entry_secure(@output_dir)
      FileUtils.remove_entry_secure(@untar_dir)
    end

    it 'creates a valid stemcell tarball in the output directory' do
      expect {
        Stemcell::Packager.package('foo-iaas',
                                   'bar-os',
                                   false,
                                   '9999.99',
                                   @image.path,
                                   @manifest.path,
                                   @apply_spec.path,
                                   @output_dir)
      }.not_to raise_error

      output_files = Dir[File.join(@output_dir, '*')]
      expect(output_files.length).to eq(1)

      stemcell_tarball_file = 'bosh-stemcell-9999.99-foo-iaas-bar-os-go_agent.tgz'
      expect(File.basename(output_files[0])).to eq(stemcell_tarball_file)

      expect { tgz_extract(output_files[0], @untar_dir) }.not_to raise_error

      stemcell_files = Dir[File.join(@untar_dir, '*')]
      expect(stemcell_files.length).to eq(3)

      expect(FileUtils.compare_file(@manifest.path,
                                    File.join(@untar_dir,
                                              'stemcell.MF'))).to be_truthy
      expect(FileUtils.compare_file(@image.path,
                                    File.join(@untar_dir,
                                              'image'))).to be_truthy
      expect(FileUtils.compare_file(@apply_spec.path,
                                    File.join(@untar_dir,
                                              'apply_spec.yml'))).to be_truthy
    end

    context 'when a light stemcell is specified' do
      it 'creates a stemcell tarball that starts with "light-"' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     true,
                                     '',
                                     @image.path,
                                     @manifest.path,
                                     @apply_spec.path,
                                     @output_dir)
        }.not_to raise_error

        output_files = Dir[File.join(@output_dir, '*')]
        expect(output_files.length).to eq(1)

        expect(File.basename(output_files[0])).to start_with('light-')
      end

      it 'creates an empty image file' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     true,
                                     '',
                                     'invalid_path',
                                     @manifest.path,
                                     @apply_spec.path,
                                     @output_dir)
        }.not_to raise_error

        output_files = Dir[File.join(@output_dir, '*')]
        expect(output_files.length).to eq(1)

        expect { tgz_extract(output_files[0], @untar_dir) }.not_to raise_error

        stemcell_files = Dir[File.join(@untar_dir, '*')]
        expect(stemcell_files.length).to eq(3)

        expect(File.size(File.join(@untar_dir, 'image'))).to eq(0)
      end
    end

    context 'when provided an invalid image path' do
      it 'raises InvalidImagePathError' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     false,
                                     '',
                                     'invalid_path',
                                     @manifest.path,
                                     @apply_spec.path,
                                     @output_dir)
        }.to raise_error(Stemcell::Packager::InvalidImagePathError)
      end
    end

    context 'when provided an invalid manifest path' do
      it 'raises InvalidManifestPathError' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     false,
                                     '',
                                     @image.path,
                                     'invalid_path',
                                     @apply_spec.path,
                                     @output_dir)
        }.to raise_error(Stemcell::Packager::InvalidManifestPathError)
      end
    end

    context 'when provided an invalid apply spec path' do
      it 'raises InvalidApplySpecPathError' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     false,
                                     '',
                                     @image.path,
                                     @manifest.path,
                                     'invalid_path',
                                     @output_dir)
        }.to raise_error(Stemcell::Packager::InvalidApplySpecPathError)
      end
    end

    context 'when provided an invalid output directory' do
      it 'raises InvalidOutputDirError' do
        expect {
          Stemcell::Packager.package('',
                                     '',
                                     false,
                                     '',
                                     @image.path,
                                     @manifest.path,
                                     @apply_spec.path,
                                     'invalid_path')
        }.to raise_error(Stemcell::Packager::InvalidOutputDirError)
      end
    end
  end
end
