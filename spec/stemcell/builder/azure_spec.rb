require 'stemcell/builder'
require 'downloader'

describe Stemcell::Builder do
  output_directory = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      output_directory = dir
      example.run
    end
  end

  describe 'Azure' do
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
        disk_image_url = 'some-disk-image-url'
        client_id = 'some-client-id'
        client_secret = 'some-client-secret'
        tenant_id = 'some-tenant-id'
        subscription_id = 'some-subscription-id'
        resource_group_name = 'some-resource-group-name'
        storage_account = 'some-storage-account'
        location = 'some-location'
        vm_size = 'some-vm-size'
        publisher = 'some-publisher'
        offer = 'some-offer'
        sku = 'some-sku'
        vm_prefix = 'some-vm-prefix'
        packer_output = "azure-arm,artifact,0\\nOSDiskUriReadOnlySas: #{disk_image_url}"

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return(config)
        allow(Packer::Config::Azure).to receive(:new).with(
          client_id: client_id,
          client_secret: client_secret,
          tenant_id: tenant_id,
          subscription_id: subscription_id,
          resource_group_name: resource_group_name,
          storage_account: storage_account,
          location: location,
          vm_size: vm_size,
          output_directory: output_directory,
          os: os,
          vm_prefix: vm_prefix,
          mount_ephemeral_disk: false,
        ).and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with(command, packer_vars).
          and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with(config).and_return(packer_runner)

        azure_manifest = double(:azure_manifest)
        allow(azure_manifest).to receive(:dump).and_return(manifest_contents)
        azure_apply = double(:azure_apply)
        allow(azure_apply).to receive(:dump).and_return(apply_spec_contents)

        allow(Stemcell::Manifest::Azure).to receive(:new).with(version,
                                                               os,
                                                               publisher,
                                                               offer,
                                                               sku).and_return(azure_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(azure_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'azure-hyperv',
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

        stemcell_path = Stemcell::Builder::Azure.new(
          os: os,
          output_directory: output_directory,
          version: version,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          client_id: client_id,
          client_secret: client_secret,
          tenant_id: tenant_id,
          subscription_id: subscription_id,
          resource_group_name: resource_group_name,
          storage_account: storage_account,
          location: location,
          vm_size: vm_size,
          publisher: publisher,
          offer: offer,
          sku: sku,
          vm_prefix: vm_prefix,
          mount_ephemeral_disk: 'false',
        ).build
        expect(stemcell_path).to eq('path-to-stemcell')
      end
    end
  end

  describe 'handles mount_ephemeral_disk correctly' do
    it 'when parameter is set to true' do
      actual = Stemcell::Builder::Azure.new(
        client_id: '',
        client_secret: '',
        tenant_id: '',
        subscription_id: '',
        resource_group_name: '',
        storage_account: '',
        location: '',
        vm_size: '',
        publisher: '',
        offer: '',
        sku: '',
        vm_prefix:'',
        os: '',
        output_directory: '',
        version: '',
        agent_commit: '',
        packer_vars: '',
        mount_ephemeral_disk: 'true'
      )

      expect(actual.instance_variable_get(:@mount_ephemeral_disk)).to equal(true)
    end

    it 'when parameter is set to false' do
      actual = Stemcell::Builder::Azure.new(
        client_id: '',
        client_secret: '',
        tenant_id: '',
        subscription_id: '',
        resource_group_name: '',
        storage_account: '',
        location: '',
        vm_size: '',
        publisher: '',
        offer: '',
        sku: '',
        vm_prefix:'',
        os: '',
        output_directory: '',
        version: '',
        agent_commit: '',
        packer_vars: '',
        mount_ephemeral_disk: 'false'
      )

      expect(actual.instance_variable_get(:@mount_ephemeral_disk)).to equal(false)
    end

    it 'when parameter is missing' do
      actual = Stemcell::Builder::Azure.new(
        client_id: '',
        client_secret: '',
        tenant_id: '',
        subscription_id: '',
        resource_group_name: '',
        storage_account: '',
        location: '',
        vm_size: '',
        publisher: '',
        offer: '',
        sku: '',
        vm_prefix:'',
        os: '',
        output_directory: '',
        version: '',
        agent_commit: '',
        packer_vars: ''
      )

      expect(actual.instance_variable_get(:@mount_ephemeral_disk)).to equal(false)
    end
  end

end
