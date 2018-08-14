require 'stemcell/builder'

describe Stemcell::Builder do
  output_directory = ''
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
  packer_command = 'build'
  packer_vars = {some_var: 'some-value'}
  packer_output = ''
  http_proxy =  'some-http-proxy'
  https_proxy = 'some-https-proxy'
  bypass_list = 'some-bypass-list'

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_directory = dir
      File.open("#{dir}/some_vmdk.vmdk", "w") do |f|
        f.write("VMDK File")
      end

      File.open("#{dir}/stembuild_output.tgz", "w") do |f|
        f.write("Stembuild Output")
      end

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
        packer_command = 'build'
        packer_vars = {some_var: 'some-value'}
        version = 'stemcell-version'
        agent_commit = 'some-agent-commit'
        os = 'windows2012R2'
        http_proxy =  'some-http-proxy'
        https_proxy = 'some-https-proxy'
        bypass_list = 'some-bypass-list'

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(packer_command, packer_vars).and_return(0)
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
          bypass_list: bypass_list,
          mount_ephemeral_disk: false,
        ).and_return(packer_config)

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
          bypass_list: bypass_list,
          mount_ephemeral_disk: "false",
        ).build
        expect(packer_runner).to have_received(:run).with(packer_command, packer_vars)
      end

      context 'when packer fails' do
        it 'raises an error' do
          source_path = 'source-path'
          administrator_password = 'my-password'
          mem_size = 1024
          num_vcpus = 1
          config = 'some-packer-config'
          packer_command = 'build'
          packer_vars = {some_var: 'some-value'}
          version = 'stemcell-version'
          agent_commit = 'some-agent-commit'
          os = 'windows2012R2'
          http_proxy =  'some-http-proxy'
          https_proxy = 'some-https-proxy'
          bypass_list = 'some-bypass-list'

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with(packer_command, packer_vars).and_return(1)
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
            bypass_list: bypass_list,
            mount_ephemeral_disk: false,
          ).and_return(packer_config)

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
      it 'builds a windows2012R2 stemcell tarball' do
        os = 'windows2012R2'
        packer_config = double(:packer_config)
        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(packer_command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)
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
          new_password: '',
          skip_windows_update: false,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list,
          mount_ephemeral_disk: true,
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
          bypass_list: bypass_list,
          mount_ephemeral_disk: 'true',
        )
        stembuild = double(:stembuild)
        allow(Stemcell::Builder::VSphere::Stembuild).to receive(:new).with("#{output_directory}/some_vmdk.vmdk", "stemcell-version", "#{output_directory}", '2012R2').and_return(stembuild)
        allow(stembuild).to receive(:run)

        builder.build
      end

      it 'builds a windows2016 stemcell tarball' do
        os = 'windows2016'
        packer_config = double(:packer_config)
        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(packer_command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)
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
          new_password: '',
          skip_windows_update: false,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list,
          mount_ephemeral_disk: true,
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
          bypass_list: bypass_list,
          mount_ephemeral_disk: 'true',
          )
        stembuild = double(:stembuild)
        allow(Stemcell::Builder::VSphere::Stembuild).to receive(:new).with("#{output_directory}/some_vmdk.vmdk", "stemcell-version", "#{output_directory}", '2016').and_return(stembuild)
        allow(stembuild).to receive(:run)

        builder.build
      end

      it 'builds a windows1803 stemcell tarball' do
        os = 'windows1803'
        packer_config = double(:packer_config)
        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(packer_command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)
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
          new_password: '',
          skip_windows_update: false,
          http_proxy: http_proxy,
          https_proxy: https_proxy,
          bypass_list: bypass_list,
          mount_ephemeral_disk: true,
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
          bypass_list: bypass_list,
          mount_ephemeral_disk: 'true',
          )
        stembuild = double(:stembuild)
        allow(Stemcell::Builder::VSphere::Stembuild).to receive(:new).with("#{output_directory}/some_vmdk.vmdk", "stemcell-version", "#{output_directory}", '1803').and_return(stembuild)
        allow(stembuild).to receive(:run)

        builder.build
      end

      context 'stembuild error handling' do
        it 'raises an error when no files match extension' do
          File.delete("#{output_directory}/some_vmdk.vmdk")
          packer_config = double(:packer_config)
          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with(packer_command, packer_vars).
            and_yield(packer_output).and_return(0)
          allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)
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
            new_password: '',
            skip_windows_update: false,
            http_proxy: http_proxy,
            https_proxy: https_proxy,
            bypass_list: bypass_list,
            mount_ephemeral_disk: true,
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
            bypass_list: bypass_list,
            mount_ephemeral_disk: 'true',
            )

          expect{builder.build}.to raise_error("No vmdk files in directory: #{output_directory}")
        end

        it 'raises an error when more than one file match extension' do
          File.open("#{output_directory}/another_vmdk.vmdk", "w") do |f|
            f.write("VMDK File")
          end
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
          packer_command = 'build'
          packer_vars = {some_var: 'some-value'}
          packer_output = ''
          http_proxy =  'some-http-proxy'
          https_proxy = 'some-https-proxy'
          bypass_list = 'some-bypass-list'

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).and_yield(packer_output).and_return(0)
          allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

          packer_config = double(:packer_config)
          allow(packer_config).to receive(:dump).and_return(config)

          allow(Packer::Config::VSphere).to receive(:new).and_return(packer_config)

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
            bypass_list: bypass_list,
            mount_ephemeral_disk: 'true',
            )

          expect {builder.build}.to raise_error(/Too many vmdk files in directory: /)
        end
      end

      context 'error handling' do
        it 'raises an error when packer fails' do
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
          packer_command = 'build'
          packer_vars = {some_var: 'some-value'}
          http_proxy =  'some-http-proxy'
          https_proxy = 'some-https-proxy'
          bypass_list = 'some-bypass-list'

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with(packer_command, packer_vars).and_return(1)
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
            new_password: '',
            skip_windows_update: false,
            http_proxy: http_proxy,
            https_proxy: https_proxy,
            bypass_list: bypass_list,
            mount_ephemeral_disk: false,
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
