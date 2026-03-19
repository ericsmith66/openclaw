FactoryBot.define do
  factory :homekit_event do
    event_type { 'characteristic_updated' }
    accessory_name { 'Front Door' }
    characteristic { 'Lock Current State' }
    value { { 'state' => 1 } }
    raw_payload { { 'type' => 'characteristic_updated' } }
    timestamp { Time.current }
  end
end
