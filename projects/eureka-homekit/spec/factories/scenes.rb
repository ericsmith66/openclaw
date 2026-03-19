FactoryBot.define do
  factory :scene do
    sequence(:name) { |n| "Scene #{n}" }
    sequence(:uuid) { |n| "scene-uuid-#{n}" }
    association :home
    metadata { {} }
  end
end
