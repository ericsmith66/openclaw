FactoryBot.define do
  factory :room do
    sequence(:name) { |n| "Room #{n}" }
    sequence(:uuid) { |n| "room-uuid-#{n}" }
    association :home
  end
end
