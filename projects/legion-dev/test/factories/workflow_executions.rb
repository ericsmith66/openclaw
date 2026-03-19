# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_execution do
    association :project
    # Removed to avoid circular dependency with workflow_run factory
    # association :workflow_run, factory: :workflow_run
    concurrency { 3 }
    phase { :decomposing }
    status { :running }
    decomposition_attempt { 0 }
    sequential { false }
    task_retry_limit { 3 }
    prd_path { "prd/requirements.md" }
  end
end
