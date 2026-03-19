# frozen_string_literal: true

module Legion
  module OrchestratorHooks
    ITERATION_THRESHOLDS = {
      "deepseek-reasoner" => 30,
      "deepseek-chat" => 30,
      "claude-sonnet-4-20250514" => 50,
      "claude-opus-4-20250514" => 50,
      "grok-4-1-fast-non-reasoning" => 100,
      "qwen3-coder-next" => 55
    }.freeze
    DEFAULT_THRESHOLD = 50

    def self.iteration_threshold_for_model(model_name)
      ITERATION_THRESHOLDS.fetch(model_name, DEFAULT_THRESHOLD)
    end
  end
end
