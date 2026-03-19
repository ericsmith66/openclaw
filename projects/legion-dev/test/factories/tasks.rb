# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    association :project
    association :team_membership
    association :workflow_run, factory: :workflow_run
    association :workflow_execution, factory: :workflow_execution
    position { 0 }
    prompt { "Test task prompt" }
    task_type { :code }
    status { :pending }
    files_score { 2 }
    concepts_score { 1 }
    dependencies_score { 1 }
    metadata { {} }
    retry_count { 0 }
    last_error { nil }
  end
end
