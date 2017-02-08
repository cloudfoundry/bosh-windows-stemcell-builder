require 'packer/runner'

describe Packer::Runner do
  describe 'run' do
    context 'when provided an invalid command' do
      it 'returns success status of false' do
        packer_runner = Packer::Runner.new('')
        success = packer_runner.run('invalid-command', {})
        expect(success).to be(false)
      end
    end
  end
end
