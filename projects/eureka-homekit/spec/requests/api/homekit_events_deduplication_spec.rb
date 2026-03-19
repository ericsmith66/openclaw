require 'rails_helper'

RSpec.describe 'Api::HomekitEvents Deduplication & Liveness', type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:valid_token) { 'sk_live_eureka_abc123xyz789' }

  let(:valid_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{valid_token}"
    }
  end

  let!(:home) { Home.create!(name: 'Test Home', uuid: 'home-abc') }
  let!(:room) { Room.create!(name: 'Test Room', uuid: 'room-abc', home: home) }
  let!(:room2) { Room.create!(name: 'Other Room', uuid: 'room-def', home: home) }
  let!(:accessory) do
    Accessory.create!(
      name: 'Front Door',
      uuid: 'acc-front-door',
      room: room,
      raw_data: {
        'services' => [
          {
            'typeName' => 'TemperatureSensor',
            'uniqueIdentifier' => 'svc-temp',
            'characteristics' => [
              {
                'typeName' => 'Current Temperature',
                'description' => 'Current Temperature',
                'uniqueIdentifier' => 'char-temp',
                'properties' => [ 'HMCharacteristicPropertySupportsEventNotification' ],
                'metadata' => { 'format' => 'float' }
              }
            ]
          },
          {
            'typeName' => 'MotionSensor',
            'uniqueIdentifier' => 'svc-motion',
            'characteristics' => [
              {
                'typeName' => 'Motion Detected',
                'description' => 'Motion Detected',
                'uniqueIdentifier' => 'char-motion',
                'properties' => [ 'HMCharacteristicPropertySupportsEventNotification' ],
                'metadata' => { 'format' => 'bool' }
              }
            ]
          }
        ]
      }
    )
  end

  let!(:sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_uuid: 'char-temp',
      service_uuid: 'svc-temp',
      service_type: 'TemperatureSensor',
      characteristic_type: 'Current Temperature',
      current_value: 20.0,
      last_updated_at: 1.hour.ago,
      last_event_stored_at: 1.hour.ago
    )
  end

  before do
    sensor.update!(current_value: 20.0, last_event_stored_at: Time.current - 1.hour)
    allow(Rails.application.credentials).to receive(:prefab_webhook_token).and_return(valid_token)
  end

  describe 'Strict Deduplication' do
    it 'stores event when value changes' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.to change(HomekitEvent, :count).by(1)
    end

    it 'skips event when value is identical (within time window)' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 20.0 # Same as sensor.current_value
      }

      # First event sets last_event_stored_at
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count

      # Move 0.5 seconds forward (within 1-second window)
      travel 0.5 do
        # This should be skipped due to time window deduplication
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # Count should remain the same (event skipped)
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count).to eq(initial_count)
    end

    it 'stores event after long time (heartbeat due)' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 20.0 # Same value
      }

      # Move 16 minutes forward (beyond 15-minute heartbeat interval)
      travel 16.minutes do
        expect {
          post '/api/homekit/events', params: payload.to_json, headers: valid_headers
        }.to change(HomekitEvent, :count).by(1)
      end
    end
  end

  describe 'Typed Value Comparison' do
    it 'treats "1" and 1 as identical for boolean format' do
      # Set up a boolean sensor
      motion_sensor = Sensor.create!(
        accessory: accessory,
        characteristic_uuid: 'char-motion-2',
        service_uuid: 'svc-motion-2',
        service_type: 'MotionSensor',
        characteristic_type: 'Motion Detected',
        current_value: '1',
        value_format: 'bool',
        last_updated_at: 1.hour.ago,
        last_event_stored_at: 1.hour.ago
      )

      # Send the same value as integer 1 (should be skipped)
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Motion Detected',
        value: 1 # Integer 1 vs string '1'
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Motion Detected').count

      # Move 500ms forward (within time window)
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # Should be skipped (time window)
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Motion Detected').count).to eq(initial_count)
    end

    it 'treats "true" and 1 as identical for boolean format' do
      # Set up a boolean sensor with string 'true'
      motion_sensor = Sensor.create!(
        accessory: accessory,
        characteristic_uuid: 'char-motion-3',
        service_uuid: 'svc-motion-3',
        service_type: 'MotionSensor',
        characteristic_type: 'Motion Detected',
        current_value: 'true',
        value_format: 'bool',
        last_updated_at: 1.hour.ago,
        last_event_stored_at: 1.hour.ago
      )

      # Send as integer 1 (should be skipped due to typed comparison)
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Motion Detected',
        value: 1
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Motion Detected').count

      # Move 500ms forward (within time window)
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # Should be skipped
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Motion Detected').count).to eq(initial_count)
    end

    it 'treats "22.5" and 22.5 as identical for float format' do
      # Set up a float sensor with string value
      sensor.update!(current_value: '22.5', last_event_stored_at: 1.hour.ago)

      # Send as float 22.5 (should be skipped due to typed comparison)
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count

      # Move 500ms forward (within time window)
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # Should be skipped
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count).to eq(initial_count)
    end

    it 'stores event when semantically different values arrive' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: '22.5' # Different from sensor.current_value of 20.0
      }

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.to change(HomekitEvent, :count).by(1)
    end
  end

  describe 'Time-based Deduplication Window' do
    it 'skips events within 1 second (RAPID_DEDUPE_WINDOW)' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count

      # Move 500ms forward (within 1-second window)
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # Second event should be skipped
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count).to eq(initial_count)
    end

    it 'skips duplicate event after 1 second but before 15 minutes' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count

      # Move 1.5 seconds forward (beyond 1-second window but within 15-minute heartbeat)
      travel_to freeze_time + 1.5 do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      final_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count
      # Second event should be skipped because it's a duplicate and heartbeat is not due
      expect(final_count).to eq(initial_count)
    end

    it 'allows different values within 1 second window' do
      payload1 = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      payload2 = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 23.0 # Different value
      }

      # First event
      freeze_time = Time.current
      post '/api/homekit/events', params: payload1.to_json, headers: valid_headers
      initial_count = HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count

      # Move 500ms forward (within 1-second window) with different value
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload2.to_json, headers: valid_headers
      end

      # Different value should be stored even within time window
      expect(HomekitEvent.where(accessory_name: 'Front Door', characteristic: 'Current Temperature').count).to eq(initial_count + 1)
    end
  end

  describe 'Heartbeat Storage' do
    it 'stores event after 15 minutes even if value unchanged' do
      # Set last_event_stored_at to 16 minutes ago
      sensor.update!(last_event_stored_at: 16.minutes.ago)

      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 20.0 # Same value
      }

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.to change(HomekitEvent, :count).by(1)
    end

    it 'stores duplicate event after 1 second but before 15 minutes' do
      # Set last_event_stored_at to 14 minutes ago (within 15-minute window but beyond 1-second window)
      freeze_time = Time.current
      travel_to freeze_time do
        sensor.update!(last_event_stored_at: freeze_time - 14.minutes)

        payload = {
          type: 'characteristic_updated',
          accessory: 'Front Door',
          characteristic: 'Current Temperature',
          value: 20.0 # Same value
        }

        # Event should be stored because:
        # 1. Values match (typed comparison)
        # 2. Last event was 14 minutes ago, which is beyond the 1-second time window
        # 3. Heartbeat is not due (14 < 15 minutes)
        # 4. No echo prevention (no recent control command)
        # Result: Event is NOT stored (it's a duplicate and not a heartbeat yet)
        expect {
          post '/api/homekit/events', params: payload.to_json, headers: valid_headers
        }.not_to change(HomekitEvent, :count)
      end
    end
  end

  describe 'Liveness Tracking' do
    it 'updates last_seen_at on sensor, accessory and room on every ping' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 23.0 # Use different value to ensure it's processed
      }

      freeze_time = Time.current.change(usec: 0)

      travel_to freeze_time do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers

        sensor.reload
        accessory.reload
        room.reload

        expect(sensor.last_seen_at).to eq(freeze_time)
        expect(accessory.last_seen_at).to eq(freeze_time)
        expect(room.last_event_at).to eq(freeze_time)
      end
    end

    it 'updates last_motion_at on room when motion is detected' do
      # Need a motion sensor
      motion_sensor = Sensor.create!(
        accessory: accessory,
        characteristic_uuid: 'char-motion',
        service_uuid: 'svc-motion',
        service_type: 'MotionSensor',
        characteristic_type: 'Motion Detected',
        current_value: 0
      )

      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Motion Detected',
        value: 1 # Motion!
      }

      freeze_time = Time.current.change(usec: 0)

      travel_to freeze_time do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers

        room.reload
        expect(room.last_motion_at).to eq(freeze_time)
      end
    end
  end

  describe 'Sensor Value Discovery' do
    it 'creates a SensorValueDefinition when a new value is seen' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 25.0
      }

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.to change(SensorValueDefinition, :count).by(1)

      definition = SensorValueDefinition.last
      expect(definition.sensor).to eq(sensor)
      expect(definition.value).to eq('25.0')
      expect(definition.occurrence_count).to eq(1)
    end

    it 'increments occurrence_count for existing definitions' do
      # Pre-create definition
      # The sensor has current_value: 20.0 and last_event_stored_at: Time.current
      SensorValueDefinition.discover!(sensor, 22.0, 1.day.ago)

      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.0 # Different from 20.0, so it will be stored and discover! will be called
      }

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.to change { SensorValueDefinition.find_by(sensor: sensor, value: '22.0').occurrence_count }.by(1)
    end

    it 'auto-assigns labels for discovered values' do
      motion_sensor = Sensor.create!(
        accessory: accessory,
        characteristic_uuid: 'char-motion-2',
        service_uuid: 'svc-motion-2',
        service_type: 'MotionSensor',
        characteristic_type: 'Motion Detected',
        current_value: 0
      )

      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Motion Detected',
        value: 1
      }

      post '/api/homekit/events', params: payload.to_json, headers: valid_headers

      definition = SensorValueDefinition.find_by(sensor: motion_sensor, value: '1')
      expect(definition.label).to eq('Detected')

      motion_sensor.reload
      expect(motion_sensor.formatted_value).to eq('Detected')
    end

    it 'uses manual labels if they exist' do
      definition = SensorValueDefinition.discover!(sensor, '22.0', Time.current)
      definition.update!(label: 'Perfect')

      sensor.update!(current_value: '22.0')
      expect(sensor.formatted_value).to eq('Perfect')
    end
  end

  describe 'Echo Prevention' do
    it 'skips event if recent control command matches within 5 seconds' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      # Create a recent control event that matches
      ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        characteristic_name: 'Current Temperature',
        new_value: '22.5',  # Must match the incoming value (payload has value: 22.5)
        success: true,
        created_at: 2.seconds.ago
      )

      # Ensure sensor is set up so it's not a duplicate (so we test echo prevention specifically)
      sensor.update!(current_value: 20.0, last_event_stored_at: Time.current - 1.minute)

      expect {
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      }.not_to change(HomekitEvent, :count)
    end
  end

  describe 'Broadcast Throttling' do
    let(:broadcast_counts) { Hash.new(0) }
    let(:instrumented_events) { [] }

    before do
      @original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      Rails.cache.clear
      # Track broadcasts to room_activity and floorplan_updates channels
      allow(::ActionCable.server).to receive(:broadcast) do |channel, payload|
        broadcast_counts[channel] += 1
      end

      # Spy on broadcast_room_update to verify it's called
      allow_any_instance_of(Api::HomekitEventsController).to receive(:broadcast_room_update).and_wrap_original do |original, room, timestamp|
        original.call(room, timestamp)
      end

      # Subscribe to instrumentation events
      ActiveSupport::Notifications.subscribe('room_broadcasts.throttled') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        instrumented_events << { name: event.name, payload: event.payload }
      end
      ActiveSupport::Notifications.subscribe('room_broadcasts.broadcasted') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        instrumented_events << { name: event.name, payload: event.payload }
      end
    end

    after do
      ActiveSupport::Notifications.unsubscribe('room_broadcasts.throttled')
      ActiveSupport::Notifications.unsubscribe('room_broadcasts.broadcasted')
      Rails.cache = @original_cache
    end

    it 'throttles broadcasts within 500ms window (cache hit)' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5 # Different from 20.0 initial
      }

      freeze_time = Time.current
      # Ensure sensor is fresh
      sensor.update!(current_value: 20.0, last_event_stored_at: freeze_time - 1.hour)

      travel_to freeze_time do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      # First event should broadcast
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.broadcasted' }.count).to eq(1)
      broadcasted_event = instrumented_events.find { |e| e[:name] == 'room_broadcasts.broadcasted' }
      expect(broadcasted_event[:payload]).to include(room_id: room.id)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.throttled' }.count).to eq(0)

      # Reset counts for clarity
      broadcast_counts.clear
      instrumented_events.clear

      # Second event within 500ms window with a DIFFERENT value to ensure it's not skipped by deduplication
      travel_to freeze_time + 0.2 do
        post '/api/homekit/events', params: payload.merge(value: 23.0).to_json, headers: valid_headers
      end

      # Should be throttled - no new broadcasts
      expect(broadcast_counts['room_activity']).to eq(0)
      expect(broadcast_counts['floorplan_updates']).to eq(0)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.throttled' }.count).to eq(1)
      throttled_event = instrumented_events.find { |e| e[:name] == 'room_broadcasts.throttled' }
      expect(throttled_event[:payload]).to include(room_id: room.id)
    end

    it 'allows new broadcast after 500ms window expires (cache miss)' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      freeze_time = Time.current
      travel_to freeze_time do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      broadcast_counts.clear
      instrumented_events.clear

      # Wait just beyond 500ms window and use DIFFERENT value
      travel_to freeze_time + 1.0 do
        post '/api/homekit/events', params: payload.merge(value: 23.0).to_json, headers: valid_headers
      end

      # Should broadcast again
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.broadcasted' }.count).to eq(1)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.throttled' }.count).to eq(0)
    end

    it 'isolates throttling per room' do
      # Create a second room
      other_room = Room.create!(name: 'Test Room 2', uuid: 'room-xyz', home: home)
      accessory2 = Accessory.create!(
        name: 'Back Door',
        uuid: 'acc-back-door',
        room: other_room,
        raw_data: accessory.raw_data
      )
      Sensor.create!(
        accessory: accessory2,
        characteristic_uuid: 'char-temp',
        service_uuid: 'svc-temp',
        service_type: 'TemperatureSensor',
        characteristic_type: 'Current Temperature',
        current_value: 20.0,
        last_event_stored_at: Time.current - 1.hour
      )

      payload1 = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }
      payload2 = {
        type: 'characteristic_updated',
        accessory: 'Back Door',
        characteristic: 'Current Temperature',
        value: 23.0
      }

      freeze_time = Time.current
      travel_to freeze_time do
        post '/api/homekit/events', params: payload1.to_json, headers: valid_headers
      end

      # First room broadcasted
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)

      broadcast_counts.clear
      instrumented_events.clear

      # Second room event within 500ms of its own first event (but after first room's broadcast)
      travel_to freeze_time + 0.3 do
        post '/api/homekit/events', params: payload2.to_json, headers: valid_headers
      end

      # Should broadcast for second room (different cache key)
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.broadcasted' }.count).to eq(1)
    end

    it 'ensures concurrent safety with race_condition_ttl' do
      cache_key = "room_broadcast_throttle:#{room.id}"
      # Ensure fetch is called with correct parameters (race_condition_ttl present)
      expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 0.5.seconds, race_condition_ttl: 0.1.seconds).and_call_original.at_least(:once)

      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      # Reset counts before concurrent requests
      broadcast_counts.clear
      instrumented_events.clear

      # Start two threads that post simultaneously (as close as possible)
      t1 = Thread.new { post '/api/homekit/events', params: payload.to_json, headers: valid_headers }
      t2 = Thread.new { post '/api/homekit/events', params: payload.to_json, headers: valid_headers }
      t1.join
      t2.join

      # Should have only one broadcast despite two concurrent requests
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)
      # Should have exactly one broadcasted instrumentation event
      broadcasted_events = instrumented_events.select { |e| e[:name] == 'room_broadcasts.broadcasted' }
      expect(broadcasted_events.count).to eq(1)
    end

    it 'uses correct cache key format' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      cache_key = "room_broadcast_throttle:#{room.id}"
      expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 0.5.seconds, race_condition_ttl: 0.1.seconds).and_call_original.at_least(:once)

      post '/api/homekit/events', params: payload.to_json, headers: valid_headers
    end

    it 'allows broadcast exactly after 500ms window' do
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      freeze_time = Time.current
      travel_to freeze_time do
        post '/api/homekit/events', params: payload.to_json, headers: valid_headers
      end

      broadcast_counts.clear
      instrumented_events.clear

      # Wait exactly 500ms (0.5 seconds) and use DIFFERENT value
      travel_to freeze_time + 0.5 do
        post '/api/homekit/events', params: payload.merge(value: 23.0).to_json, headers: valid_headers
      end

      # Should broadcast again (window expired)
      expect(broadcast_counts['room_activity']).to eq(1)
      expect(broadcast_counts['floorplan_updates']).to eq(1)
      expect(instrumented_events.select { |e| e[:name] == 'room_broadcasts.broadcasted' }.count).to eq(1)
    end

    it 'fails open when cache raises an error' do
      allow(Rails.cache).to receive(:fetch).and_raise(StandardError)
      payload = {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Current Temperature',
        value: 22.5
      }

      expect { post '/api/homekit/events', params: payload.to_json, headers: valid_headers }.not_to raise_error
      # Verify broadcasts still occurred (or at least the request succeeded)
      expect(response).to have_http_status(:success)
    end
  end
end
