# frozen_string_literal: true

FactoryBot.define do
  factory :task_dependency do
    association :task
    association :depends_on_task, factory: :task
  end
end
