FactoryBot.define do
  factory :accessory do
    sequence(:name) { |n| "Accessory #{n}" }
    sequence(:uuid) { |n| "accessory-uuid-#{n}" }
    association :room
    characteristics { {} }
  end
end
