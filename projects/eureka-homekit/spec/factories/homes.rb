FactoryBot.define do
  factory :home do
    sequence(:name) { |n| "Home #{n}" }
    sequence(:uuid) { |n| "home-uuid-#{n}" }
    homekit_home_id { SecureRandom.uuid }
  end
end
