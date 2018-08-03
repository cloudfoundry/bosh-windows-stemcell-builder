require 'stemcell/builder'

describe Stemcell::Builder do
  before(:each) do
    @original_env = ENV.to_hash
  end

  after(:each) do
    ENV.replace(@original_env)
  end

  describe 'validate_env' do
    context 'when an environment variable is missing' do
      it 'raises' do
        expect{ Stemcell::Builder::validate_env('VARIABLE') }.to raise_error(Stemcell::Builder::EnvironmentValidationError, /missing/)
      end
    end

    context 'when an environment variable exists' do
      it 'returns that variable' do
        ENV['VARIABLE'] = 'i exist'
        actual = Stemcell::Builder::validate_env('VARIABLE')
        expect(actual).to eq('i exist')
      end
    end
  end

  describe 'validate_env_dir' do
    context 'when the directory a variable references does not exist' do
      it 'raises' do
        ENV['VARIABLE'] = 'nonexistent_directory'
        expect{ Stemcell::Builder::validate_env_dir('VARIABLE') }.to raise_error(Stemcell::Builder::EnvironmentValidationError, /directory/)
      end
    end

    context 'when the directory a variable references exists' do
      it 'returns that variable' do
        env_dir = Dir.mktmpdir('base')
        ENV['VARIABLE'] = env_dir
        actual = Stemcell::Builder::validate_env('VARIABLE')
        expect(actual).to eq(env_dir)
      end
    end
  end

  describe 'Base' do
    context 'initialize handles mount_ephemeral_disk' do
      it 'handles true parameter' do
        actual = Stemcell::Builder::Base.new(
          os: '',
          output_directory: '',
          version: '',
          agent_commit: '',
          packer_vars: '',
          mount_ephemeral_disk: 'true'
        )
        expect(actual.instance_variable_get(:@mount_ephemeral_disk)).to equal(true)
      end

      it 'handles false parameter' do
        actual = Stemcell::Builder::Base.new(
          os: '',
          output_directory: '',
          version: '',
          agent_commit: '',
          packer_vars: '',
          mount_ephemeral_disk: 'false'
        )
        expect(actual.instance_variable_get(:@mount_ephemeral_disk)).to equal(false)

      end
      it 'handles missing parameter' do
        actual = Stemcell::Builder::Base.new(
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
end
