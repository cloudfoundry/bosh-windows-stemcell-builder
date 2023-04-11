require 'stemcell/builder'

describe Stemcell::Builder do
  output_directory = ''
  ami_output_directory = ''

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      Dir.mktmpdir do |ami_dir|
        ami_output_directory = ami_dir
        output_directory = dir
        example.run
      end
    end
  end

  describe 'Aws' do
    describe 'build' do
      it 'builds a stemcell tarball' do
        os = 'windows2012R2'
        version = '1234.0'
        amis = 'some-amis'
        agent_commit = 'some-agent-commit'
        packer_output = ",artifact,0,id,some-region-id:some-ami-id"
        parsed_packer_amis = [{'region' => 'some-region-id', 'ami_id' => 'some-ami-id'}]
        aws_access_key = 'some-aws-access-key'
        aws_secret_key = 'some-aws-secret-key'
        packer_vars = 'some-packer-vars'
        region = 'some-region'
        vm_prefix = 'some-vm-prefix'

        packer_config = double(:packer_config)
        allow(packer_config).to receive(:dump).and_return('some-packer-config')
        allow(Packer::Config::Aws).to receive(:new)
          .with(aws_access_key: aws_access_key,
                aws_secret_key: aws_secret_key,
                aws_role_arn: '',
                region: amis,
                output_directory: output_directory,
                os: os,
                version: version,
                vm_prefix: vm_prefix,
                mount_ephemeral_disk: false,
              )
          .and_return(packer_config)

        packer_runner = double(:packer_runner)
        allow(packer_runner).to receive(:run).with('build', packer_vars).and_yield(packer_output).and_return(0)
        allow(Packer::Runner).to receive(:new).with('some-packer-config').and_return(packer_runner)

        aws_manifest = double(:aws_manifest)
        allow(aws_manifest).to receive(:dump).and_return('manifest-contents')
        aws_apply = double(:aws_apply)
        allow(aws_apply).to receive(:dump).and_return('apply-spec-contents')
        allow(Stemcell::Manifest::Aws).to receive(:new).with(version, os, parsed_packer_amis).and_return(aws_manifest)
        allow(Stemcell::ApplySpec).to receive(:new).with(agent_commit).and_return(aws_apply)
        allow(Stemcell::Packager).to receive(:package).with(iaas: 'aws-xen-hvm',
                                                            os: os,
                                                            is_light: true,
                                                            version: version,
                                                            image_path: '',
                                                            manifest: 'manifest-contents',
                                                            apply_spec: 'apply-spec-contents',
                                                            output_directory: output_directory,
                                                            update_list: nil,
                                                            region: region
                                                           ).and_return('path-to-stemcell')

        stemcell_path = Stemcell::Builder::Aws.new(
          os: os,
          output_directory: output_directory,
          version: version,
          ami: amis,
          aws_access_key: aws_access_key,
          aws_secret_key: aws_secret_key,
          agent_commit: agent_commit,
          packer_vars: packer_vars,
          region: region,
          vm_prefix: vm_prefix,
          mount_ephemeral_disk: 'false'
        ).build_from_packer(ami_output_directory)
        expect(stemcell_path).to eq('path-to-stemcell')
      end

      context 'when packer fails' do
        it 'raises an error' do
          amis = 'some-amis'
          aws_access_key = 'some-aws-access-key'
          aws_secret_key = 'some-aws-secret-key'
          packer_vars = 'some-packer-vars'
          os = 'windows2012R2'
          vm_prefix = 'some-vm-prefix'

          packer_config = double(:packer_config)
          allow(packer_config).to receive(:dump).and_return('some-packer-config')
          allow(Packer::Config::Aws).to receive(:new)
            .with(aws_access_key: aws_access_key,
                  aws_secret_key: aws_secret_key,
                  aws_role_arn: '',
                  region: amis,
                  output_directory: output_directory,
                  os: os,
                  version: '',
                  vm_prefix: vm_prefix,
                  mount_ephemeral_disk: false,
                )
            .and_return(packer_config)

          packer_runner = double(:packer_runner)
          allow(packer_runner).to receive(:run).with('build', packer_vars).and_return(1)
          allow(Packer::Runner).to receive(:new).with('some-packer-config').and_return(packer_runner)

          expect {
            Stemcell::Builder::Aws.new(
              os: os,
              output_directory: output_directory,
              version: '',
              ami: amis,
              aws_access_key: aws_access_key,
              aws_secret_key: aws_secret_key,
              agent_commit: '',
              packer_vars: packer_vars,
              vm_prefix: vm_prefix
            ).build_from_packer(ami_output_directory)
          }.to raise_error(Stemcell::Builder::PackerFailure)
        end
      end
    end
  end
end
