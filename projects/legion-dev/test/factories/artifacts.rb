# frozen_string_literal: true

FactoryBot.define do
  factory :artifact do
    association :project
    association :workflow_run
    association :workflow_execution
    association :created_by, factory: :agent_team
    artifact_type { "plan" }
    content { "Test content" }
    name { "Artifact #{SecureRandom.uuid}" }
    parent_artifact { nil }
    metadata { {} }
  end
end
