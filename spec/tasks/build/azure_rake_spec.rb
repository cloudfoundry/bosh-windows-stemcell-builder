# frozen_string_literal: true

require 'rake'
load File.expand_path('../../../lib/tasks/build/azure.rake', __dir__)

describe 'build:azure' do
  let(:task) { Rake::Task['build:azure'] }
  let(:azure_builder_class) { class_double(Stemcell::Builder::Azure).as_stubbed_const }
  let(:azure_builder_instance) { instance_double(Stemcell::Builder::Azure) }

  before do
    Rake::Task.define_task(:environment)

    allow(Stemcell::Builder).to receive(:validate_env_dir)
      .and_return('version_dir')
    allow(File).to receive(:expand_path).with(any_args).and_return('build_root')
    allow(File).to receive(:read).with('version_dir/number')
                                 .and_return('1709.10.43-build.1')
    allow(File).to receive(:read).with('build_root/compiled-agent/sha')
                                 .and_return('some_sha')
    allow(File).to receive(:absolute_path).with('bosh-windows-stemcell')
                                          .and_return('some_output_directory')
    allow(azure_builder_class).to receive(:new)
      .with(any_args).and_return(azure_builder_instance)
    allow(azure_builder_instance).to receive(:build).with(no_args)
  end

  context 'handles ephemeral disk' do
    let(:env_var) { 'some_env_var' }

    before do
      # This allows the task to be ran multiple times in different tests.
      task.reenable

      allow(Stemcell::Builder).to receive(:validate_env).with(any_args)
                                                        .and_return(env_var)
      allow(ENV).to receive(:fetch).with('VM_PREFIX', '')
                                   .and_return('some_prefix')
    end

    it 'when environment variable set to true' do
      allow(ENV).to receive(:fetch).with('MOUNT_EPHEMERAL_DISK', 'false')
                                   .and_return('true')

      expect(azure_builder_class).to receive(:new).with(
        packer_vars: {},
        version: '1709.10.43-build.1',
        agent_commit: 'some_sha',
        os: env_var,
        output_directory: 'some_output_directory',
        client_id: env_var,
        client_secret: env_var,
        tenant_id: env_var,
        subscription_id: env_var,
        resource_group_name: env_var,
        storage_account: env_var,
        location: env_var,
        vm_size: env_var,
        publisher: env_var,
        offer: env_var,
        sku: env_var,
        vm_prefix: 'some_prefix',
        mount_ephemeral_disk: 'true'
      )

      expect(azure_builder_instance).to receive(:build).with(no_args)

      task.invoke

    end

    it 'when environment variable set to false' do
      allow(ENV).to receive(:fetch).with('MOUNT_EPHEMERAL_DISK', 'false')
                                   .and_return('false')

      expect(azure_builder_class).to receive(:new).with(
        packer_vars: {},
        version: '1709.10.43-build.1',
        agent_commit: 'some_sha',
        os: env_var,
        output_directory: 'some_output_directory',
        client_id: env_var,
        client_secret: env_var,
        tenant_id: env_var,
        subscription_id: env_var,
        resource_group_name: env_var,
        storage_account: env_var,
        location: env_var,
        vm_size: env_var,
        publisher: env_var,
        offer: env_var,
        sku: env_var,
        vm_prefix: 'some_prefix',
        mount_ephemeral_disk: 'false'
      )

      expect(azure_builder_instance).to receive(:build).with(no_args)

      task.invoke
    end

    it 'when environment variable is missing' do
      allow(ENV).to receive(:fetch).with('MOUNT_EPHEMERAL_DISK', 'false')
                                   .and_call_original

      expect(azure_builder_class).to receive(:new).with(
        packer_vars: {},
        version: '1709.10.43-build.1',
        agent_commit: 'some_sha',
        os: env_var,
        output_directory: 'some_output_directory',
        client_id: env_var,
        client_secret: env_var,
        tenant_id: env_var,
        subscription_id: env_var,
        resource_group_name: env_var,
        storage_account: env_var,
        location: env_var,
        vm_size: env_var,
        publisher: env_var,
        offer: env_var,
        sku: env_var,
        vm_prefix: 'some_prefix',
        mount_ephemeral_disk: 'false'
      )

      expect(azure_builder_instance).to receive(:build).with(no_args)

      task.invoke
    end
  end
end
