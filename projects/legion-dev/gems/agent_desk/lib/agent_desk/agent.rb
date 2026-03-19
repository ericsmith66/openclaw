# frozen_string_literal: true

module AgentDesk
  # Namespace for the agent execution layer.
  module Agent
  end
end

require_relative "agent/cost_calculator"
require_relative "agent/token_budget_tracker"
require_relative "agent/usage_logger"
require_relative "agent/state_snapshot"
require_relative "agent/compaction_strategy"
require_relative "agent/runner"
require_relative "agent/profile"
require_relative "agent/profile_manager"
