require 'stemcell/builder'

describe Stemcell::Builder do
  output_directory = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_directory = dir
      example.run
    end
  end

  describe 'GCP' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        agent_commit = 'some-agent-commit'
        config = 'some-packer-config'
        command = 'build'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        packer_vars = {some_var: 'some-value'}
        image_name = 'some-image-name'
        image_url = "https://www.googleapis.com/compute/v1/projects/some-project-id/global/images/#{image_name}"
        account_json = {'project_id' => 'some-project-id'}.to_json
        packer_output = ",artifact,0,id,#{image_name}"
        source_image = "some-source-image"
        image_family= "some-family"
        vm_prefix = "some-vm-prefix"

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Gcp).to receive(:new).with(
          account_json, 'some-project-id', source_image, output_directory, image_family, os, vm_prefix
        ).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        gcp_manifest = double(:gcp_manifest)
        allow(gcp_manifest).to receive(:dump).and_return(manifest_contents)
        gcp_apply = double(:gcp_apply)
        allow(gcp_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Gcp).to receive(:new).with(version, os, image_url).and_return(gcp_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(gcp_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'google-kvm',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: manifest_contents,
                                                            apply_spec: apply_spec_contents,
                                                            output_directory: output_directory,
                                                            update_list: nil,
                                                            region: nil
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Gcp.new(
          os: os,
          output_directory: output_directory,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          account_json: account_json,
          source_image: source_image,
          image_family: image_family,
          vm_prefix: vm_prefix
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end

      context 'when packer fails' do
        it 'raises an error' do
          project_id = 'some-project-id'
          account_json = {'project_id' => project_id}.to_json
          source_image = "some-source-image"
          image_family = "some-family"
          packer_vars = 'some-packer-vars'
          os = 'windows2012R2'
          vm_prefix = 'some-vm-prefix'

          packer_config = double(:packer_config)
          allow(packer_config).to receive(:dump).and_return('some-packer-config')
          allow(Packer::Config::Gcp).to receive(:new).with(
            account_json, project_id, source_image, output_directory, image_family, os, vm_prefix
          ).and_return(packer_config)

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with('build', packer_vars).and_return(1)
          allow(Packer::Runner).to receive(:new).with('some-packer-config').and_return(packer_runner)

          expect {
            Stemcell::Builder::Gcp.new(
              os: os,
              output_directory: output_directory,
              version: '',
              agent_commit: '',
              packer_vars: packer_vars,
              account_json: account_json,
              source_image: source_image,
              image_family: image_family,
              vm_prefix: vm_prefix
            ).build
          }.to raise_error(Stemcell::Builder::PackerFailure)
        end
      end
    end
  end
end
