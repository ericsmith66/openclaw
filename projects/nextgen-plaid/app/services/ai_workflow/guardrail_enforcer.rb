# frozen_string_literal: true

module AiWorkflow
  class GuardrailEnforcer
    def self.enforce_turn_limit!(result, max_turns:, artifacts:)
      turns = (result.context[:turns_count] || 0).to_i
      return if turns < max_turns

      result.context[:workflow_state] = "escalated_to_human"
      artifacts.record_event(type: "max_turns_exceeded", turns_count: turns, max_turns: max_turns)
      raise AiWorkflowService::EscalateToHumanError, "max turns exceeded"
    end
  end
end
