SPEC_ROOT = File.dirname(__FILE__).freeze
REPO_ROOT = Pathname(SPEC_ROOT).parent
$LOAD_PATH.unshift("#{REPO_ROOT}/lib")

require "stemcell/builder"

require "timecop"
require "zip"

require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

Dir[REPO_ROOT.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.max_formatted_output_length = 10_000
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before do
    allow(Output).to receive(:say) # reduce output in specs
  end
end
