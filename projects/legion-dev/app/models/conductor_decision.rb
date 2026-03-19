# frozen_string_literal: true

class ConductorDecision < ApplicationRecord
  belongs_to :workflow_execution

  enum :decision_type, {
    approve: "approve",
    reject_decision: "reject",
    modify_decision: "modify",
    escalate_decision: "escalate"
  }, validate: true

  # Scopes
  scope :chronological, -> { order(created_at: :asc) }
  scope :for_execution, ->(execution_id) { where(workflow_execution_id: execution_id) }

  # Alias for testing enum values
  def reject?
    decision_type == "reject_decision"
  end

  validate :payload_is_valid_json

  def payload_is_valid_json
    if payload.is_a?(String) && !payload.empty?
      begin
        JSON.parse(payload)
      rescue JSON::ParserError
        errors.add(:payload, "must be valid JSON")
      end
    end
  end
end
