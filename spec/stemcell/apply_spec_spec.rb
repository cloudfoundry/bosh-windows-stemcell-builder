require 'stemcell/apply_spec'

describe Stemcell::ApplySpec do
  describe 'dump' do
    it 'returns a valid apply_spec json string' do
      apply_spec_str = Stemcell::ApplySpec.new('commit').dump
      expect(JSON.parse(apply_spec_str)).to eq(
        'agent_commit' => 'commit'
      )
    end
  end
end
