require 'stemcell/packager'
require 'rubygems/package'

describe Stemcell::Packager do
  before(:each) do
    @image = Tempfile.new('')
    @update_list = Tempfile.new('')
    File.open(@image.path, 'w') { |f| f.write('image-contents') }
    File.open(@update_list.path, 'w') { |f| f.write('update-list-contents') }

    @output_directory = Dir.mktmpdir
    @untar_dir = Dir.mktmpdir
  end

  after(:each) do
    @image.unlink
    @update_list.unlink
    FileUtils.remove_entry_secure(@output_directory)
    FileUtils.remove_entry_secure(@untar_dir)
  end

  describe 'find_ovf_file' do
    it 'returns the filename of the ovf file in directory' do
      ovf_dir = Dir.mktmpdir
      ovf_filename = 'image.ovf'
      ovf_path = File.join(ovf_dir, ovf_filename)

      File.open(ovf_path, 'w') { |f| f.write('image-contents') }

      expect(Stemcell::Packager.find_ovf_file(ovf_dir)).to eq(ovf_path)

      FileUtils.remove_entry_secure(ovf_dir)
    end
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

  describe 'aggregate the amis' do
    it 'creates a single tar file' do
      amis_path = File.join(File.expand_path('../../..', __FILE__), 'spec', 'fixtures', 'aws', 'amis')
      output_dir = Dir.mktmpdir
      Stemcell::Packager.aggregate_the_amis(amis_path, output_dir, 'some-region-1')

      stemcell_path = File.join(output_dir, 'light-bosh-stemcell-1089.0-aws-xen-hvm-windows2012R2-go_agent.tgz')
      expect(File.exist?(stemcell_path)).to eq(true)
    end

    it 'aggregates the amis inside the tar file' do
      amis_path = File.join(File.expand_path('../../..', __FILE__), 'spec', 'fixtures', 'aws', 'amis')
      output_dir = Dir.mktmpdir

      Stemcell::Packager.aggregate_the_amis(amis_path, output_dir, 'some-region-1')

      stemcell_path = File.join(output_dir, 'light-bosh-stemcell-1089.0-aws-xen-hvm-windows2012R2-go_agent.tgz')

      stemcell_manifest_contents = read_from_tgz(stemcell_path, "stemcell.MF")
      manifest = YAML.load(stemcell_manifest_contents)
      amis = manifest['cloud_properties']['ami']

      expect(amis['some-region-2']).to eq("some-ami-2")
      expect(amis['some-region-1']).to eq("some-ami-1")
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
                                   update_list:  @update_list.path,
                                   manifest:  'some-manifest',
                                   apply_spec:  'some-apply-spec',
                                   output_directory:  @output_directory)
      }.not_to raise_error

      expect(Dir[File.join(@output_directory, '*')].length).to eq(2)
      tgz_file = Dir[File.join(@output_directory, '*.tgz')].first
      sha_file = Dir[File.join(@output_directory, '*.sha')].first

      stemcell_tarball_file = 'bosh-stemcell-9999.99-foo-iaas-bar-os-go_agent.tgz'
      expect(File.basename(tgz_file)).to eq(stemcell_tarball_file)

      stemcell_tarball_sha_file = 'bosh-stemcell-9999.99-foo-iaas-bar-os-go_agent.tgz.sha'
      expect(File.basename(sha_file)).to eq(stemcell_tarball_sha_file)
      expect(File.read(sha_file)).to eq(Digest::SHA1.hexdigest(File.read(tgz_file)))

      expect { tgz_extract(tgz_file, @untar_dir) }.not_to raise_error

      stemcell_files = Dir[File.join(@untar_dir, '*')]
      expect(stemcell_files.length).to eq(4)

      expect(File.read(File.join(@untar_dir, 'stemcell.MF'))).to eq('some-manifest')
      expect(FileUtils.compare_file(@image.path,
                                    File.join(@untar_dir,
                                              'image'))).to be_truthy
      expect(FileUtils.compare_file(@update_list.path,
                                    File.join(@untar_dir,
                                              'updates.txt'))).to be_truthy
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
                                     output_directory: @output_directory,
                                     update_list: @update_list.path)
        }.not_to raise_error

        output_files = Dir[File.join(@output_directory, '*')]
        expect(output_files.length).to eq(2)

        expect(File.basename(output_files[0])).to start_with('light-')
        expect(File.basename(output_files[1])).to start_with('light-')
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
                                     output_directory: @output_directory,
                                     update_list: @update_list.path)
        }.not_to raise_error

        tgz_file = Dir[File.join(@output_directory, '*.tgz')].first
        expect(Dir[File.join(@output_directory, '*')].length).to eq(2)

        expect { tgz_extract(tgz_file, @untar_dir) }.not_to raise_error

        stemcell_files = Dir[File.join(@untar_dir, '*')]
        expect(stemcell_files.length).to eq(4)

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
                                     output_directory: @output_directory,
                                     update_list: @update_list.path)
        }.not_to raise_error

        expect(Dir[File.join(@output_directory, '*')].length).to eq(2)
        tgz_file = Dir[File.join(@output_directory, '*.tgz')].first
        sha_file = Dir[File.join(@output_directory, '*.sha')].first

        expect(File.read(sha_file)).to eq(Digest::SHA1.hexdigest(File.read(tgz_file)))
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
                                     output_directory: @output_directory,
                                     update_list: @update_list.path)
        }.to raise_error(Stemcell::Packager::InvalidImagePathError)
      end
    end

    context 'when provided an invalid update list path' do
      it 'should not write an updates.txt file' do
        expect {
          Stemcell::Packager.package(iaas: '',
                                     os: '',
                                     is_light: false,
                                     version: '',
                                     image_path: @image.path,
                                     manifest:  'some-manifest',
                                     apply_spec:  'some-apply-spec',
                                     output_directory: @output_directory,
                                     update_list: nil)
        }.not_to raise_error

        tgz_file = Dir[File.join(@output_directory, '*.tgz')].first
        expect { tgz_extract(tgz_file, @untar_dir) }.not_to raise_error

        stemcell_files = Dir[File.join(@untar_dir, '*')]
        expect(stemcell_files).not_to include('updates.txt')
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
                                     output_directory: 'invalid_path',
                                     update_list: @update_list.path)
        }.to raise_error(Stemcell::Packager::InvalidOutputDirError)
      end
    end
  end
end
