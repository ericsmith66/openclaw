# frozen_string_literal: true

module AgentDesk
  module ToolApprovalState
    ALWAYS = "always"
    ASK    = "ask"
    NEVER  = "never"
  end

  module ReasoningEffort
    NONE   = "none"
    LOW    = "low"
    MEDIUM = "medium"
    HIGH   = "high"
  end

  module ContextMemoryMode
    OFF       = "off"
    RELEVANT  = "relevant"
    FULL      = "full"
  end

  module InvocationMode
    ON_DEMAND = "on_demand"
    ALWAYS    = "always"
  end

  # Lightweight data class for context messages
  ContextMessage = Data.define(:id, :role, :content, :prompt_context)

  # Lightweight data class for context files
  ContextFile = Data.define(:path, :read_only) do
    def initialize(path:, read_only: false)
      super
    end
  end

  # Subagent configuration (nested in profile)
  SubagentConfig = Data.define(
    :enabled, :system_prompt, :invocation_mode, :color, :description, :context_memory
  ) do
    def initialize(
      enabled: false,
      system_prompt: "",
      invocation_mode: InvocationMode::ON_DEMAND,
      color: "#3368a8",
      description: "",
      context_memory: ContextMemoryMode::OFF
    )
      super
    end
  end
end
