FactoryBot.define do
  factory :sensor do
    association :accessory
    sequence(:service_uuid) { |n| "service-uuid-#{n}" }
    service_type { "Temperature Sensor" }
    sequence(:characteristic_uuid) { |n| "char-uuid-#{n}" }
    characteristic_type { "Current Temperature" }
    value_format { "float" }
  end
end
