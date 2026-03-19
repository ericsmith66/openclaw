# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    name { "Legion" }
    sequence(:path) { |n| "/tmp/test/project-#{n}" }
    project_rules { {} }
  end
end
