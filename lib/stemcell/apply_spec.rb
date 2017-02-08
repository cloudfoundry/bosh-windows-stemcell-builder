module Stemcell
  class ApplySpec
    def initialize(agent_commit)
      @agent_commit = agent_commit
    end

    def dump
      JSON.dump(
        'agent_commit' => @agent_commit
      )
    end
  end
end
