# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_run do
    association :project
    association :team_membership
    # Removed to avoid circular dependency with workflow_execution factory
    # association :workflow_execution, factory: :workflow_execution
    prompt { "Test prompt" }
    status { :queued }
    iterations { 0 }
    metadata { {} }
  end
end
