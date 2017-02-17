require 'packer/runner'

describe Packer::Runner do
  describe 'run' do
    it 'streams packer output and returns its exit status' do
      temp_file = Tempfile.new('')
      config = {
        "builders" => [{
          "type" => "file",
          "content" => "contents",
          "target" => temp_file.path
        }]
      }.to_json
      packer_runner = Packer::Runner.new(config)
      block_evaluated = false
      exit_status = packer_runner.run('build') do |stdout|
        stdout.each_line do |line|
          if line.include?(",ui,say,Build 'file' finished.")
            block_evaluated = true
          end
        end
      end
      expect(block_evaluated).to be_truthy
      expect(exit_status).to eq(0)
    end

    context 'when arguments are provided' do
      it 'passes them to packer' do
        temp_file = Tempfile.new('')
        contents = 'some-contents'
        config = {
          "builders" => [{
            "type" => "file",
            "content" => "{{user `contents`}}",
            "target" => temp_file.path
          }]}.to_json
        packer_runner = Packer::Runner.new(config)
        packer_runner.run('build', {contents: contents})
        expect(File.read(temp_file.path)).to eq(contents)
      end
    end

    context 'when provided an invalid command' do
      it 'returns a non-zero exit status' do
        packer_runner = Packer::Runner.new('{}')
        exit_status, _ = packer_runner.run('invalid-command', {})
        expect(exit_status).not_to eq(0)
      end
    end
  end
end
