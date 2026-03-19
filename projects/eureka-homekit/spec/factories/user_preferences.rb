FactoryBot.define do
  factory :user_preference do
    sequence(:session_id) { |n| "session-#{n}" }
    favorites { [] }
    favorites_order { [] }
  end
end
