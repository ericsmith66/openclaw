# frozen_string_literal: true

FactoryBot.define do
  factory :agent_team do
    association :project
    sequence(:name) { |n| "ROR-#{n}" }
    description { "Rails development team" }
    team_rules { {} }
  end
end
