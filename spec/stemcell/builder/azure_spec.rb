require 'stemcell/builder'

describe Stemcell::Builder do
  output_dir = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_dir = dir
      example.run
    end
  end

  describe 'Azure' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        name = 'bosh-azure-stemcell-name'
        config = 'some-packer-config'
        command = 'build'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        packer_vars = {some_var: 'some-value'}
        downloaded_image_path = File.join(output_dir, 'root.vhd')
        File.new(downloaded_image_path, "w+")
        packaged_image_path = File.join(output_dir, 'image')
        File.new(packaged_image_path, 'w+')
        sha = Digest::SHA1.file(packaged_image_path).hexdigest
        packer_output = "azure-arm,artifact,0\\nOSDiskUriReadOnlySas: file://#{downloaded_image_path}"

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Azure).to receive(:new).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        allow(Stemcell::Packager).to receive(:package_image)
          .with(image_path: downloaded_image_path, archive: true, output_dir: output_dir)
          .and_return(packaged_image_path)

        azure_manifest = double(:azure_manifest)
        allow(azure_manifest).to receive(:dump).and_return(manifest_contents)
        azure_apply = double(:azure_apply)
        allow(azure_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Azure).to receive(:new).with(name, version, sha, os).and_return(azure_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(azure_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'azure',
                                                            os: os,
                                                            is_light: false,
                                                            version: version,
                                                            image_path: packaged_image_path,
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
                                                            output_dir: output_dir
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Azure.new(
          os: os,
          output_dir: output_dir,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end
end
