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
        http_proxy =  'some-http-proxy'
        https_proxy = 'some-https-proxy'
        bypass_list = 'some-bypass-list'

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
          os: os,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list).and_return(packer_config)

        Stemcell::Builder::VSphereAddUpdates.new(
          os: os,
          version: version,
          agent_commit: agent_commit,
          source_path: source_path,
          administrator_password: administrator_password,
          mem_size: mem_size,
          num_vcpus: num_vcpus,
          output_directory: output_directory,
          packer_vars: packer_vars,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list
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
          http_proxy =  'some-http-proxy'
          https_proxy = 'some-https-proxy'
          bypass_list = 'some-bypass-list'

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
            os: os,
            http_proxy: http_proxy,
            https_proxy: https_proxy,
            bypass_list: bypass_list).and_return(packer_config)

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
              packer_vars: packer_vars,
              http_proxy: http_proxy,
              https_proxy: https_proxy,
              bypass_list: bypass_list
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
        agent_commit = 'some-agent-commit'
        os = 'windows2012R2'
        command = 'build'
        packer_vars = {some_var: 'some-value'}
        packer_output = ''
        http_proxy =  'some-http-proxy'
        https_proxy = 'some-https-proxy'
        bypass_list = 'some-bypass-list'

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
          os: os,
          enable_rdp: false,
          enable_kms: false,
          kms_host: '',
          new_password: '',
          skip_windows_update: false,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list
        ).and_return(packer_config)

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
          new_password: '',
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list
        )
        allow(builder).to receive(:run_packer)
        allow(builder).to receive(:run_stembuild)
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
          http_proxy =  'some-http-proxy'
          https_proxy = 'some-https-proxy'
          bypass_list = 'some-bypass-list'

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
            os: os,
            enable_rdp: false,
            enable_kms: false,
            kms_host: '',
            new_password: '',
            skip_windows_update: false,
            http_proxy: http_proxy,
            https_proxy: https_proxy,
            bypass_list: bypass_list
          ).and_return(packer_config)

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
              new_password: '',
              http_proxy: http_proxy,
              https_proxy: https_proxy,
              bypass_list: bypass_list
            ).build }.to raise_error(Stemcell::Builder::PackerFailure)
        end
      end
    end
  end
end
