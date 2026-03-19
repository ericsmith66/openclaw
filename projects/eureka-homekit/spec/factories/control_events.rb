FactoryBot.define do
  factory :control_event do
    association :accessory, factory: :accessory
    action_type { 'set_characteristic' }
    success { true }
    latency_ms { 100.0 }
  end
end
