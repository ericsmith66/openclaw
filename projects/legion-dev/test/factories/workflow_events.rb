# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_event do
    association :workflow_run
    event_type { "agent.started" }
    channel { "agent.started" }
    agent_id { "test-agent" }
    recorded_at { Time.current }
    payload { {} }
  end
end
