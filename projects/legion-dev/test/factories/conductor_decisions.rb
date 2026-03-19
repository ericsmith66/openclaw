# frozen_string_literal: true

FactoryBot.define do
  factory :conductor_decision do
    association :workflow_execution
    decision_type { "approve" }
    payload { { test: "data" } }
    tool_name { "dispatch_decompose" }
    tool_args { { "reasoning" => "Test reasoning" } }
    from_phase { "planning" }
    to_phase { "decomposing" }
    reasoning { "Test reasoning for decision" }
    input_summary { { "prompt" => "Test prompt", "trigger" => "start" }.to_json }
    duration_ms { 100 }
    tokens_used { 1200 }
    estimated_cost { 0.36 }
  end
end
