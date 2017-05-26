require 'stemcell/builder'

describe Stemcell::Builder do
  output_directory = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_directory = dir
      example.run
    end
  end

  describe 'VSphereAddUpdates' do
    describe 'build' do
      it 'builds a vmx from a source vmx' do
        source_path = 'source-path'
        administrator_password = 'my-password'
        mem_size = 1024
        num_vcpus = 1
        config = 'some-packer-config'
        command = 'build'
        packer_vars = {some_var: 'some-value'}
        version = 'stemcell-version'
        agent_commit = 'some-agent-commit'
        os = 'windows2012R2'

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)

        allow(Packer::Config::VSphereAddUpdates).to receive(:new).with(
          administrator_password: administrator_password,
          source_path: source_path,
          output_directory: output_directory,
          mem_size: mem_size,
          num_vcpus: num_vcpus,
          os: os).and_return(packer_config)

        Stemcell::Builder::VSphereAddUpdates.new(
          os: os,
          version: version,
          agent_commit: agent_commit,
          source_path: source_path,
          administrator_password: administrator_password,
          mem_size: mem_size,
          num_vcpus: num_vcpus,
          output_directory: output_directory,
          packer_vars: packer_vars
        ).build
        expect(packer_runner).to have_received(:run).with(command, packer_vars)
      end

      context 'when packer fails' do
        it 'raises an error' do
          source_path = 'source-path'
          administrator_password = 'my-password'
          mem_size = 1024
          num_vcpus = 1
          config = 'some-packer-config'
          command = 'build'
          packer_vars = {some_var: 'some-value'}
          version = 'stemcell-version'
          agent_commit = 'some-agent-commit'
          os = 'windows2012R2'

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with(command, packer_vars).and_return(1)
          allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

          packer_config = double(:packer_config)
          allow(packer_config).to receive(:dump).and_return(config)

          allow(Packer::Config::VSphereAddUpdates).to receive(:new).with(
            administrator_password: administrator_password,
            source_path: source_path,
            output_directory: output_directory,
            mem_size: mem_size,
            num_vcpus: num_vcpus,
            os: os).and_return(packer_config)

          expect {
            Stemcell::Builder::VSphereAddUpdates.new(
              os: os,
              version: version,
              agent_commit: agent_commit,
              source_path: source_path,
              administrator_password: administrator_password,
              mem_size: mem_size,
              num_vcpus: num_vcpus,
              output_directory: output_directory,
              packer_vars: packer_vars
            ).build }.to raise_error(Stemcell::Builder::PackerFailure)
        end

        it 'does not add the VM to the VMX directory' do
        end
      end
    end
  end

  describe 'VSphere' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        source_path = 'source-path'
        administrator_password = 'my-password'
        product_key = 'product-key'
        owner = 'owner'
        organization = 'organization'
        mem_size = '4'
        num_vcpus = '8'
        config = 'some-packer-config'
        version = 'stemcell-version'
        manifest_contents = 'manifest_contents'
        apply_spec_contents = 'apply_spec_contents'
        agent_commit = 'some-agent-commit'
        sha = 'sha'
        os = 'windows2012R2'
        image = 'some-image'
        command = 'build'
        packer_vars = {some_var: 'some-value'}
        packer_output = ''

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)

        allow(Packer::Config::VSphere).to receive(:new).with(
          administrator_password: administrator_password,
          source_path: source_path,
          output_directory: output_directory,
          mem_size: mem_size,
          num_vcpus: num_vcpus,
          product_key: product_key,
          owner: owner,
          organization: organization,
          os: os).and_return(packer_config)

        vsphere_manifest = double(:vsphere_manifest)
        allow(vsphere_manifest).to receive(:dump).and_return(manifest_contents)

        vsphere_apply = double(:vsphere_apply)
        allow(vsphere_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::VSphere).to receive(:new).with(version, sha, os).and_return(vsphere_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(vsphere_apply)
        allow(Stemcell::Packager).to receive(:package).with(
          iaas: 'vsphere-esxi',
          os: os,
          is_light: false,
          version: version,
          image_path: image,
          manifest: manifest_contents,
          apply_spec: apply_spec_contents,
          output_directory: output_directory,
          update_list: nil
        ).and_return('path-to-stemcell')

        builder = Stemcell::Builder::VSphere.new(
          os: os,
          output_directory: output_directory,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          administrator_password: administrator_password,
          source_path: source_path,
          mem_size: mem_size,
          num_vcpus: num_vcpus,
          product_key: product_key,
          owner: owner,
          organization: organization,
        )
        allow(builder).to receive(:create_image).and_return([image,sha])
        expect(builder.build).to eq('path-to-stemcell')
      end

      context 'when packer fails' do
        it 'raises an error' do
          source_path = 'source-path'
          administrator_password = 'my-password'
          product_key = 'product-key'
          owner = 'owner'
          organization = 'organization'
          mem_size = '4'
          num_vcpus = '8'
          config = 'some-packer-config'
          version = 'stemcell-version'
          agent_commit = 'some-agent-commit'
          os = 'windows2012R2'
          command = 'build'
          packer_vars = {some_var: 'some-value'}

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with(command, packer_vars).and_return(1)
          allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

          packer_config = double(:packer_config)
          allow(packer_config).to receive(:dump).and_return(config)

          allow(Packer::Config::VSphere).to receive(:new).with(
            administrator_password: administrator_password,
            source_path: source_path,
            output_directory: output_directory,
            mem_size: mem_size,
            num_vcpus: num_vcpus,
            product_key: product_key,
            owner: owner,
            organization: organization,
            os: os).and_return(packer_config)

          expect {
            Stemcell::Builder::VSphere.new(
              os: os,
              output_directory: output_directory,
              version: version,
              agent_commit: agent_commit,
              packer_vars: packer_vars,
              administrator_password: administrator_password,
              source_path: source_path,
              mem_size: mem_size,
              num_vcpus: num_vcpus,
              product_key: product_key,
              owner: owner,
              organization: organization,
            ).build }.to raise_error(Stemcell::Builder::PackerFailure)
        end
      end
    end
  end
end
